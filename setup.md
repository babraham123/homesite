# Setup website files

## Install tools
```bash
brew install python
pip install mkdocs-material "mkdocs-material[imaging]" mkdocstrings mkdocs-rss-plugin mkdocs-awesome-nav
brew install cairo freetype libffi libjpeg libpng zlib pngquant
brew link expat --force

git clone https://github.com/babraham123/homesite
```

Consider creating a gravatar profile for comments: https://gravatar.com/

## Update the guides folder
```bash
cd ../homelab
tools/render_guides.sh ../homesite/src/www/docs/guides
cd ../homesite
```

## Render and install source
```bash
tools/deploy_src.sh
```

# Test locally
```bash
open assets/www/index.html
```
