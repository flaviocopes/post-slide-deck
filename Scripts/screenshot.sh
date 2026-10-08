#!/bin/sh
# Renders the main window and every slide of a library from the real app views.
# It compiles PostdeckCore into a static library, then the app's views with
# Scripts/screenshot.swift in place of the @main file, into an app with its own bundle ID.
# Usage: ./Scripts/screenshot.sh <library folder> [output folder, default: docs]
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LIBRARY=$(CDPATH= cd -- "$1" && pwd)
OUTPUT="${2:-docs}"
mkdir -p "$OUTPUT"
OUTPUT=$(CDPATH= cd -- "$OUTPUT" && pwd)
BUILD="$ROOT/.build/screenshot"
APP="$BUILD/Post Slide Deck Screenshot.app"
TARGET="$(uname -m)-apple-macos14.0"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 6 -parse-as-library -target "$TARGET" -module-name PostdeckCore \
  -emit-library -static -emit-module -emit-module-path "$BUILD/PostdeckCore.swiftmodule" \
  -o "$BUILD/libPostdeckCore.a" Sources/PostdeckCore/*.swift
find Sources/PostdeckApp -name '*.swift' ! -exec grep -q '^@main' {} \; -exec \
  swiftc -O -swift-version 6 -parse-as-library -target "$TARGET" -I "$BUILD" -L "$BUILD" -lPostdeckCore \
  -o "$APP/Contents/MacOS/Screenshot" Scripts/screenshot.swift {} +

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Screenshot</string>
  <key>CFBundleIdentifier</key>
  <string>com.flaviocopes.postdeck.screenshot</string>
  <key>CFBundleName</key>
  <string>Post Slide Deck</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
open -n "$APP" --args "$OUTPUT" "$LIBRARY" -AppleLocale en_US -AppleLanguages '(en)'
sleep 1
while pgrep -f "Post Slide Deck Screenshot.app/Contents/MacOS" >/dev/null; do sleep 1; done
ls "$OUTPUT"
