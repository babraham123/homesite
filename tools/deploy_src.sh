#!/usr/bin/env bash
# Renders the source code and uploads it to the homelab server as a new release, then
# switches the site to it. Keeps the last few releases for tools/rollback.sh.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/deploy_src.sh

set -euo pipefail

source tools/server.sh

require_server
tools/render_src.sh

release="$(date -u +%Y%m%dT%H%M%SZ)"
scp -qr -o LogLevel=QUIET assets "$server:homesite-$release"
echo "$host root password:"
ssh -t "$server" "
set -euo pipefail
cd '$nginx_dir'
sudo mkdir -p releases
# One-time migration from a plain www directory, which a symlink can't replace in place.
if [ -d www ] && [ ! -L www ]; then
  sudo mv www releases/00000000T000000Z
  sudo ln -s releases/00000000T000000Z www
fi
sudo chown -R root:root ~/homesite-$release
sudo mv ~/homesite-$release 'releases/$release'
$(switch_release_cmd "$release")
ls -1 releases | sort | head -n -$releases_kept | while read -r old; do
  sudo rm -rf \"releases/\$old\"
done
"

echo "Deployed release $release to $host.$url"
