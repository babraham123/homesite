#!/usr/bin/env bash
# Shared by the scripts that change the live site. Source it, don't run it.
# shellcheck disable=SC2034  # used by the scripts that source this

host="websvcs"
url="bket.net"
user="manualadmin"
server="$user@$host.$url"

# nginx serves /var/opt/nginx/www, a symlink to one of releases/<UTC timestamp>, and
# mounts all of /var/opt/nginx so the symlink resolves inside the container too.
nginx_dir="/var/opt/nginx"
releases_kept=3

require_server() {
  if ! ping -c3 -W3 "$host.$url" > /dev/null; then
    echo "error: $host is not reachable" >&2
    exit 1
  fi
}

# Remote snippet: atomically repoint www at releases/$1. A rename replaces the old
# symlink in one step, so nginx never sees a missing or half-copied root.
switch_release_cmd() {
  echo "sudo ln -sfn \"releases/$1\" '$nginx_dir/www.new' && sudo mv -T '$nginx_dir/www.new' '$nginx_dir/www'"
}
