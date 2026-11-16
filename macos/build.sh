#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
APP="$PWD/build/ScanCode.app"
CACHE="$ROOT/.build/modulecache"
mkdir -p "$CACHE"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

ARCH="$(uname -m)"
swiftc -O -swift-version 5 \
  -module-cache-path "$CACHE" \
  -target "${ARCH}-apple-macos14.0" \
  -framework Cocoa \
  -framework ScreenCaptureKit \
  -framework Vision \
  -framework CoreImage \
  -framework Carbon \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/扫码助手"

/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null
echo "built: $APP"
"$APP/Contents/MacOS/扫码助手" --selftest
