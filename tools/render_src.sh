#!/usr/bin/env bash
# Renders the source code into the assets folder.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/render_src.sh

export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:$PKG_CONFIG_PATH"
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
export DYLD_LIBRARY_PATH="/usr/local/lib:/opt/homebrew/lib:$DYLD_LIBRARY_PATH"

set -euo pipefail

rm -rf assets/*
cp -R src/error assets
cp -R src/wifi assets

pushd src/www
mkdocs build -d ../../assets/www
popd

echo "Rendered the site's assets into $(pwd)/assets"
