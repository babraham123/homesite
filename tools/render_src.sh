#!/usr/bin/env bash
# Renders the source code into the given folder. Fills in personal details from vars.yml.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/render_src.sh /dir/to/store/rendered/copy
# Ref:
# https://manpages.debian.org/buster/fd-find/fdfind.1.en.html
# https://github.com/kpfleming/jinjanator

set -euo pipefail

project_dir=$1
rm -rf "$project_dir"
mkdir -p "$project_dir"
cp -R . "$project_dir"
pushd "$project_dir"
rm -rf .git .gitignore vars.yml .vscode
popd

fdfind="fdfind"
$fdfind -h &> /dev/null || fdfind="fd"
$fdfind . --type f --exec jinjanate --quiet -o "$project_dir/{}" "{}" vars.yml
$fdfind . --extension sh --exec chmod +x "$project_dir/{}"

rm -f "$project_dir"/**/.DS_Store
echo "Rendered the repo's source code into $project_dir"
