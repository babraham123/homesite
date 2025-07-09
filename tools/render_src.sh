#!/usr/bin/env bash
# Renders the source code into the assets folder.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/render_src.sh

set -euo pipefail

cp -R src/error assets
cp -R src/wifi assets

pushd src/www
mkdocs build -d ../assets/www
popd

echo "Rendered the site's assets into $(pwd)/assets"
