#!/usr/bin/env bash
# Apply CM Health overlay + patches onto the upstream OpenStrap Edge source tree.
set -euo pipefail
SRC="${1:?usage: apply.sh <src-dir>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1) Overlay: files copied verbatim over the source tree (icons, new files).
if [ -d "$REPO_DIR/overlay" ] && [ -n "$(find "$REPO_DIR/overlay" -type f -not -name '.gitkeep' | head -1)" ]; then
  echo "== Copying overlay files =="
  (cd "$REPO_DIR/overlay" && find . -type f -not -name '.gitkeep' -print) | sed 's|^\./||'
  rsync -a --exclude='.gitkeep' "$REPO_DIR/overlay/" "$SRC/"
fi

# 2) Patches: applied in lexical order.
shopt -s nullglob
for p in "$REPO_DIR"/patches/*.patch; do
  echo "== Applying $(basename "$p") =="
  git -C "$SRC" apply --whitespace=nowarn --verbose "$p"
done
echo "== apply.sh done =="
