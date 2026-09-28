#!/usr/bin/env bash
# Copies the homelab docs, already rendered with example values in the homelab repo's
# rendered/ folder, into the site.
# Run from root of the project directory.
# Usage:
#   tools/sync_homelab_docs.sh [path/to/homelab]

set -euo pipefail

homelab="${1:-../homelab}"
dest="src/www/docs/homelab"

rm -rf "$dest"
mkdir -p "$dest"
cp "$homelab"/rendered/docs/*.md "$dest"
cp -R "$homelab"/rendered/docs/guides "$homelab"/rendered/docs/adr "$dest"
# rendered/README.md describes the rendered copy itself, so the index comes from the
# repo README, with its docs/ links rebased onto this folder.
sed 's/(docs\/\([^)]*\)\.md)/(\1.md)/g' "$homelab/README.md" > "$dest/index.md"

echo "Synced the homelab docs into $dest"
