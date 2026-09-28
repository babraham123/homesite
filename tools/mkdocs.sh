#!/usr/bin/env bash
# Runs the pinned mkdocs from .venv inside src/www, so paths in the args are relative
# to src/www.
# Usage:
#   tools/mkdocs.sh serve
#   tools/mkdocs.sh build -d ../../assets/www

# The social plugin loads cairo through cffi, which only searches these paths.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export DYLD_LIBRARY_PATH="/opt/homebrew/lib:/usr/local/lib:${DYLD_LIBRARY_PATH:-}"

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root/src/www"
exec "$root/.venv/bin/mkdocs" "$@"
