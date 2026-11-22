#!/usr/bin/env bash
# Copy live personal files into this folder. Adds and updates only, never deletes.
# Then commit and push to `me`.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src=${XDG_CONFIG_HOME:-$HOME/.config}/hypr
for d in UserConfigs UserScripts; do
  mkdir -p "$here/$d"
  cp -a "$src/$d/." "$here/$d/"
done
