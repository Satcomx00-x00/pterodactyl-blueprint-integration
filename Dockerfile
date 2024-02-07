# Stage 0:
# Build the assets that are needed for the frontend. This build stage is then discarded
# since we won't need NodeJS anymore in the future. This Docker image ships a final production
# level distribution of Pterodactyl.
FROM --platform=linux/amd64 ubuntu:latest

ENV NODE_OPTIONS=--openssl-legacy-provider
WORKDIR /app
COPY . ./
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    npm i -g yarn

RUN yarn install --frozen-lockfile && \
    yarn run build:production

# Stage 1:
# Build the actual container with all of the needed PHP dependencies that will run the application.
FROM --platform=linux/amd64 php:8.1-fpm-bullseye
WORKDIR /app
COPY . ./
COPY --from=0 /app/public/assets ./public/assets
# dcron
RUN apt update && apt install -y ash ca-certificates curl git supervisor tar unzip libpng-dev libxml2-dev libzip-dev certbot python3-certbot-nginx netcat \
    && addgroup --system nginx \
    && adduser --system --ingroup nginx nginx \
#    && addgroup --system nginx \
#    && adduser --system --ingroup nginx nginx \
    && docker-php-ext-configure zip \
    && docker-php-ext-install bcmath gd pdo_mysql zip \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && cp .env.example .env \
    && mkdir -p bootstrap/cache/ storage/logs storage/framework/sessions storage/framework/views storage/framework/cache \
    && chmod 777 -R bootstrap storage \
    && composer install --no-dev --optimize-autoloader \
    && rm -rf .env bootstrap/cache/*.php \
    && mkdir -p /app/storage/logs/ \
    && chown -R nginx:nginx .

RUN mkdir -p /var/spool/cron/crontabs && \
    touch /var/spool/cron/crontabs/root && \
    chmod 600 /var/spool/cron/crontabs/root && \
    echo "* * * * * /usr/local/bin/php /app/artisan schedule:run >> /dev/null 2>&1" >> /var/spool/cron/crontabs/root && \
    echo "0 23 * * * certbot renew --nginx --quiet" >> /var/spool/cron/crontabs/root && \
    sed -i s/ssl_session_cache/#ssl_session_cache/g /etc/nginx/nginx.conf && \
#    rm /usr/local/etc/php-fpm.conf && \
    mkdir -p /var/run/php /var/run/nginx
#    mkdir -p /var/run/php /var/run/nginx

RUN rm /usr/local/etc/php-fpm.conf \
    && echo "* * * * * /usr/local/bin/php /app/artisan schedule:run >> /dev/null 2>&1" >> /var/spool/cron/crontabs/root \
    && echo "0 23 * * * certbot renew --nginx --quiet" >> /var/spool/cron/crontabs/root \
    && sed -i s/ssl_session_cache/#ssl_session_cache/g /etc/nginx/nginx.conf \
    && mkdir -p /var/run/php /var/run/nginx

COPY .github/docker/default.conf /etc/nginx/http.d/default.conf
COPY .github/docker/www.conf /usr/local/etc/php-fpm.conf
COPY .github/docker/supervisord.conf /etc/supervisord.conf

RUN ln -s /etc/nginx/http.d/panel.conf /etc/nginx/sites-available/panel.conf

EXPOSE 80 443
ENTRYPOINT [ "/bin/ash", ".github/docker/entrypoint.sh" ]
CMD [ "supervisord", "-n", "-c", "/etc/supervisord.conf" ]
