#!/usr/bin/env bash
# Run from root of project directory
# tools/update_src.sh
# Ref: https://jampack.divriots.com/

set -euo pipefail

user=$(yq ".username" vars.yml)
url=$(yq ".site.url" vars.yml)

rm -rf /root/homesite-rendered
git pull
tools/render_src.sh /root/homesite-rendered

cd /root/homesite-rendered
tools/render_sites.sh
npm ci
npx @divriots/jampack /root/homesite-rendered

# Copy the rendered site to the server
cd /root
scp -qr homesite-rendered "$user@websvcs.$url:/home/$user"
echo "websvcs root password:"
ssh -t "$user@websvcs.$url" '
sudo chown -R root:root homesite-rendered
sudo rm -rf /root/homesite-rendered
sudo mv homesite-rendered /root/homesite-rendered

sudo mkdir -p /var/opt/nginx/www
sudo rm -rf /var/opt/nginx/www/*
sudo mv /root/homesite-rendered/assets/* /var/opt/nginx/www
'
