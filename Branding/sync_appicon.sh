#!/usr/bin/env bash
# SVG → AppIcon PNG sizes (LifeLogger 빌드에 실제로 쓰이는 경로)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/Branding/AppIcon.svg"
TARGET="$ROOT/LifeLogger/Assets.xcassets/AppIcon.appiconset"
EXPORTER="$ROOT/Branding/export_appicon.swift"
TMP="$ROOT/Branding/.icon_build"

if [[ ! -f "$SVG" ]]; then
  echo "Missing $SVG — run: python3 Branding/make_logo.py" >&2
  exit 1
fi

mkdir -p "$TMP"
swift "$EXPORTER" "$SVG" "$TMP/master.png" 1024

render() {
  local name="$1"
  local px="$2"
  sips -z "$px" "$px" "$TMP/master.png" --out "$TARGET/$name" >/dev/null
}

render "icon_16x16.png" 16
render "icon_16x16@2x.png" 32
render "icon_32x32.png" 32
render "icon_32x32@2x.png" 64
render "icon_128x128.png" 128
render "icon_128x128@2x.png" 256
render "icon_256x256.png" 256
render "icon_256x256@2x.png" 512
render "icon_512x512.png" 512
render "icon_512x512@2x.png" 1024

rm -rf "$TMP"
echo "Synced app icon PNGs → $TARGET"
echo "Next: Product → Clean Build Folder, then rebuild and re-run the app."
