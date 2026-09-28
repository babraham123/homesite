#!/usr/bin/env bash
# Points the live site at the release before the current one. Run it again to go back
# further; the next tools/deploy_src.sh moves forward again.
# Run from root of the project directory.
# Usage:
#   cd ~/project/dir
#   tools/rollback.sh

set -euo pipefail

source tools/server.sh

require_server
echo "$host root password:"
ssh -t "$server" "
set -euo pipefail
cd '$nginx_dir'
current=\$(basename \"\$(readlink www)\")
previous=\$(ls -1 releases | sort | grep -B1 -x \"\$current\" | head -n1)
if [ -z \"\$previous\" ] || [ \"\$previous\" = \"\$current\" ]; then
  echo \"error: no release older than \$current\" >&2
  exit 1
fi
$(switch_release_cmd "\$previous")
echo \"Rolled back from \$current to \$previous\"
"
