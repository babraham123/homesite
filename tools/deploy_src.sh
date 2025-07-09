#!/usr/bin/env bash
# Renders the source code and copies it to the homelab server.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/deploy_src.sh

set -euo pipefail

host="websvcs"
url="bket.net"
user="babraham"

tools/render_src.sh

if ! ping -c3 -W3 "$host.$url" > /dev/null; then
  echo "error: $host is not reachable" >&2
  return
fi
# Copy the rendered site to the server
scp -qr -o LogLevel=QUIET assets "$user@$host.$url:/home/$user"
echo "$host root password:"
ssh -t "$user@$host.$url" '
sudo chown -R root:root assets
sudo mkdir -p /var/opt/nginx/www
sudo rm -rf /var/opt/nginx/www/*
sudo cp -r /home/babraham/assets/* /var/opt/nginx/www
sudo rm -rf /home/babraham/assets
'

echo "Deployed the site to $host.$url"
