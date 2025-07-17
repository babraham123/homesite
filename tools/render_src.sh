#!/usr/bin/env bash
# Renders the source code into the assets folder.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/render_src.sh

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
export DYLD_LIBRARY_PATH="/opt/homebrew/lib:/usr/local/lib:$DYLD_LIBRARY_PATH"

set -euo pipefail

rm -rf assets/*
cp -R src/error assets
cp -R src/wifi assets

pushd src/www
mkdocs build -d ../../assets/www
popd

echo "Rendered the site's assets into $(pwd)/assets"
