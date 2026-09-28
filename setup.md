# Setup website files

## Install tools
```bash
brew install uv lychee cairo freetype libffi libjpeg libpng zlib pngquant
brew link expat --force

git clone https://github.com/babraham123/homesite
cd homesite
uv venv && uv pip install -r requirements.txt
git config core.hooksPath .githooks
```

`requirements.txt` pins mkdocs and its plugins; bump them deliberately a couple of times a
year. `tools/mkdocs.sh` runs the pinned mkdocs from `.venv`.

The hooks in `.githooks/` check links: `pre-commit` builds the site with `--strict` and
checks internal links and anchors offline, `pre-push` checks external links.

Consider creating a gravatar profile for comments: https://gravatar.com/

## Update the guides folder
The homelab repo keeps its docs pre-rendered with example values in `rendered/`; copy
them in:
```bash
tools/sync_homelab_docs.sh ../homelab
```

## Render and install source
```bash
tools/deploy_src.sh
```

Each deploy uploads a new release to `/var/opt/nginx/releases/` on the server and
atomically points the `www` symlink at it, keeping the last 3. To go back one release:
```bash
tools/rollback.sh
```

# Test locally
```bash
tools/mkdocs.sh serve
```

Don't open the built `assets/` tree directly: it only renders correctly when served at
the configured `site_url` root, since it uses absolute paths and a fetched search index.
