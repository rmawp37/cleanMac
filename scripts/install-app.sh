#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_APP="/Applications/CleanMac.app"

"$ROOT_DIR/scripts/build-app.sh"
rm -rf "$TARGET_APP"
cp -R "$ROOT_DIR/dist/CleanMac.app" "$TARGET_APP"

echo "Installed CleanMac to $TARGET_APP"
echo "Grant Accessibility permission to $TARGET_APP, not to the swift run binary."