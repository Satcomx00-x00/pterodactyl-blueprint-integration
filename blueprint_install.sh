apt-get install -y wget zip nano
wget https://github.com/teamblueprint/main/releases/download/alpha-NLM/alpha-NLM.zip
unzip alpha-NLM.zip
find . -type f -exec sed -i 's/\/var\/www\/pterodactyl/\/app/g' {} \;
cp -r blueprint .blueprint

apt-get install -y ca-certificates curl gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs
npm i -g yarn
yarn
chmod +x blueprint.sh

./blueprint.sh

php artisan migrate --seed --force