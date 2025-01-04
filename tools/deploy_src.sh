#!/usr/bin/env bash
# Renders the source code and copies it to the homelab server.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/deploy_src.sh

set -euo pipefail

project_dir=/tmp/homesite-rendered
host="websvcs"
user=$(yq ".username" vars.yml)
url=$(yq ".site.url" vars.yml)

tools/render_src.sh "$project_dir"

pushd "$project_dir"
tools/render_sites.sh
popd

if ! ping -c3 -W3 "$host.$url" > /dev/null; then
  echo "error: $host is not reachable" >&2
  return
fi
# Copy the rendered site to the server
scp -qr -o LogLevel=QUIET "$project_dir" "$user@$host.$url:/home/$user"
echo "$host root password:"
ssh -t "$user@$host.$url" '
sudo chown -R root:root homesite-rendered
sudo rm -rf /root/homesite-rendered
sudo mv homesite-rendered /root/homesite-rendered

sudo mkdir -p /var/opt/nginx/www
sudo rm -rf /var/opt/nginx/www/*
sudo ls /root/homesite-rendered/assets | xargs -I% sudo cp -r /root/homesite-rendered/assets/% /var/opt/nginx/www
'

rm -rf "$project_dir"
