#!/bin/sh
# Builds a universal (Apple silicon and Intel) dist/Post Slide Deck.app, with the postdeck command
# at Contents/Helpers/postdeck and the agent skill at Contents/Resources/SKILL.md.
# Signs with Flavio's Developer ID when the certificate is in the keychain, and ad-hoc everywhere else (CI, forks).
# The version comes from Postdeck.version in Sources/PostdeckCore/Version.swift.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
APP="$ROOT/dist/Post Slide Deck.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICON_SOURCE="$ROOT/Assets/AppIcon.png"
ICONSET="$ROOT/.build/AppIcon.iconset"

cd "$ROOT"
VERSION=$(sed -n 's/^ *public static let version = "\(.*\)"$/\1/p' Sources/PostdeckCore/Version.swift)
swift build -c release --arch arm64 --arch x86_64 --product PostdeckApp
swift build -c release --arch arm64 --arch x86_64 --product postdeck

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$CONTENTS/Helpers"
cp ".build/apple/Products/Release/PostdeckApp" "$MACOS/Post Slide Deck"
cp ".build/apple/Products/Release/postdeck" "$CONTENTS/Helpers/postdeck"
cp skill/postdeck/SKILL.md "$RESOURCES/SKILL.md"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Post Slide Deck</string>
  <key>CFBundleExecutable</key>
  <string>Post Slide Deck</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.flaviocopes.postdeck</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Post Slide Deck</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

IDENTITY=$(security find-identity -v -p codesigning | awk '/"Developer ID Application: Flavio Copes \(DGFKNTAG99\)"/ { print $2; exit }')
if [ -n "$IDENTITY" ]; then
  SIGNATURE="Developer ID"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$CONTENTS/Helpers/postdeck"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$MACOS/Post Slide Deck"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  codesign --verify --strict "$APP"
else
  SIGNATURE="ad-hoc"
  codesign --force --deep --sign - "$APP"
  codesign --verify --deep --strict "$APP"
fi

echo "Built $APP $VERSION for $(lipo -archs "$MACOS/Post Slide Deck"), $SIGNATURE signed"
echo "$APP"
