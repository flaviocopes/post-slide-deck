#!/bin/sh
# Builds the universal app, notarizes it when it's signed with the Developer ID, and writes
# dist/Postdeck-<version>.zip for a GitHub release, with Postdeck.app and the Chrome extension
# in a "Postdeck Extension" folder next to it.
# Needs the Developer ID certificate in the keychain and a notarytool profile named "notary":
#   xcrun notarytool store-credentials notary --apple-id <apple id> --team-id DGFKNTAG99
# Usage: ./Scripts/build-release.sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
VERSION=$(sed -n 's/^ *public static let version = "\(.*\)"$/\1/p' Sources/PostdeckCore/Version.swift)
EXTENSION_VERSION=$(sed -n 's/^ *"version": "\(.*\)",$/\1/p' extension/manifest.json)
APP="$ROOT/dist/Postdeck.app"
ZIP="$ROOT/dist/Postdeck-$VERSION.zip"
STAGE=$(mktemp -d)
CHECK=$(mktemp -d)
trap 'rm -rf "$STAGE" "$CHECK"' EXIT

if [ "$VERSION" != "$EXTENSION_VERSION" ]; then
  echo "The app is $VERSION but the extension is $EXTENSION_VERSION. Make them equal." >&2
  exit 1
fi

rm -f "$ZIP"
./Scripts/build-app.sh >/dev/null
lipo "$APP/Contents/MacOS/Postdeck" -verify_arch arm64 x86_64

TEAM=$(codesign -dv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')
if [ "$TEAM" = DGFKNTAG99 ]; then
  SIGNATURE="Developer ID"
  ditto -c -k --keepParent "$APP" "$STAGE/notarize.zip"
  RESULT=$(xcrun notarytool submit "$STAGE/notarize.zip" --keychain-profile notary --wait --output-format json)
  if [ "$(printf '%s' "$RESULT" | plutil -extract status raw -o - -)" != Accepted ]; then
    printf '%s\n' "$RESULT" >&2
    xcrun notarytool log "$(printf '%s' "$RESULT" | plutil -extract id raw -o - -)" --keychain-profile notary >&2
    exit 1
  fi
  rm "$STAGE/notarize.zip"
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose "$APP"
else
  SIGNATURE="ad-hoc"
fi

ditto "$APP" "$STAGE/Postdeck.app"
ditto extension "$STAGE/Postdeck Extension"
find "$STAGE" -name .DS_Store -delete
ditto -c -k "$STAGE" "$ZIP"

ditto -x -k "$ZIP" "$CHECK"
codesign --verify --deep --strict "$CHECK/Postdeck.app"
test -f "$CHECK/Postdeck Extension/manifest.json"

echo "Built $ZIP, $SIGNATURE signed"
shasum -a 256 "$ZIP"
