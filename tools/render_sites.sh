#!/usr/bin/env bash
# Run from root of project directory
# Render the site assets in place
# tools/render_sites.sh

set -euo pipefail

sass assets-src/aerial/assets/sass/main.scss --style compressed > assets/www/assets/css/main.css
sass assets-src/aerial/assets/sass/noscript.scss --style compressed > assets/www/assets/css/noscript.css

sass assets-src/story/assets/sass/main.scss --style compressed > assets/story/assets/css/main.css
sass assets-src/story/assets/sass/noscript.scss --style compressed > assets/story/assets/css/noscript.css

sass assets-src/error/404.scss --style compressed > assets/error/404.css

cp assets-src/story/index.html assets/story/index.html
cp assets-src/www/index.html assets/www/index.html
cp assets-src/error/404.html assets/error/404.html
cp assets-src/error/403.html assets/error/403.html
cp assets-src/wifi assets/wifi

cd assets-src/blog
mkdocs build -d ../../assets/blog

cd ../..
rm -rf assets-src

echo "Rendered the site's assets into $(pwd)/assets"
