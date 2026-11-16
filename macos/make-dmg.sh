#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

APP="build/ScanCode.app"
DMG="build/ScanCode-0.1.6.dmg"
STAGE="build/dmg-stage"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/扫码助手.app"
ln -s /Applications "$STAGE/Applications"
cp DMG-README.txt "$STAGE/使用说明.txt"

hdiutil create \
  -volname "扫码助手 0.1.6" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

echo "built: $PWD/$DMG"
