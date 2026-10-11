#!/usr/bin/env bash
# LifeLogger — Developer ID archive, notarize, staple, DMG (#1)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="LifeLogger"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/LifeLogger.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/build/export}"
APP_PATH="$EXPORT_PATH/LifeLogger.app"
DMG_PATH="${DMG_PATH:-$ROOT/build/LifeLogger.dmg}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT/scripts/ExportOptions.plist}"

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM (Apple Team ID)}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE (notarytool keychain profile name)}"

echo "==> Archive"
xcodebuild archive \
  -project "$ROOT/LifeLogger.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  ENABLE_HARDENED_RUNTIME=YES

echo "==> Export (Developer ID)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "==> Notarize"
ZIP_PATH="$ROOT/build/LifeLogger-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Staple"
xcrun stapler staple "$APP_PATH"

echo "==> DMG"
rm -f "$DMG_PATH"
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg --volname "LifeLogger" --overwrite "$DMG_PATH" "$APP_PATH"
else
  STAGING="$ROOT/build/dmg-staging"
  rm -rf "$STAGING"
  mkdir -p "$STAGING"
  cp -R "$APP_PATH" "$STAGING/"
  hdiutil create -volname "LifeLogger" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
fi

echo "==> Done: $DMG_PATH"
