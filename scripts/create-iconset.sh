#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/logo.png" ]]; then
	SOURCE_LOGO="$ROOT_DIR/logo.png"
elif [[ -f "$ROOT_DIR/logo.jpg" ]]; then
	SOURCE_LOGO="$ROOT_DIR/logo.jpg"
elif [[ -f "$ROOT_DIR/logo.jpeg" ]]; then
	SOURCE_LOGO="$ROOT_DIR/logo.jpeg"
else
	echo "No source logo found. Expected logo.png, logo.jpg, or logo.jpeg in $ROOT_DIR" >&2
	exit 1
fi

ICONSET_DIR="$ROOT_DIR/Resources/AppIcon.iconset"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
TARGET_RESOURCE_LOGO="$ROOT_DIR/Sources/CleanMac/Resources/logo.png"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -s format png "$SOURCE_LOGO" --out "$TARGET_RESOURCE_LOGO" >/dev/null

sips -z 16 16 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$TARGET_RESOURCE_LOGO" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$TARGET_RESOURCE_LOGO" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

echo "Created $ICON_FILE"
echo "Updated $TARGET_RESOURCE_LOGO"