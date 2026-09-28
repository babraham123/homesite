#!/usr/bin/env bash
# Renders the source code into the assets folder.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/render_src.sh

set -euo pipefail

rm -rf assets/*
cp -R src/error assets
cp -R src/wifi assets

tools/mkdocs.sh build -d ../../assets/www

echo "Rendered the site's assets into $(pwd)/assets"
