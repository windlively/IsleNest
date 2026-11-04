#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-debug}"
PACKAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PACKAGE_DIR/build/IsleNest.app"

cd "$PACKAGE_DIR"

MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PACKAGE_DIR/Info.plist")"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"

# SwiftPM records the deployment target as the SDK version, which keeps macOS on
# the legacy window/control appearance. Record the real SDK so Liquid Glass is used.
swift build -c "$CONFIG" --product IsleNest \
    -Xlinker -platform_version -Xlinker macos -Xlinker "$MIN_MACOS" -Xlinker "$SDK_VERSION"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/IsleNest" "$APP_DIR/Contents/MacOS/IsleNest"
cp "$PACKAGE_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done

# A stable signing identity keeps TCC grants (screen recording) valid across rebuilds;
# ad-hoc signatures are cdhash-bound and silently lose them on every build.
SIGN_IDENTITY="${ISLENEST_CODESIGN_IDENTITY:-IsleNest Dev}"
if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$SIGN_IDENTITY\""; then
    codesign --force --deep --sign "$SIGN_IDENTITY" --timestamp=none "$APP_DIR" >/dev/null
    echo "Signed with $SIGN_IDENTITY" >&2
else
    codesign --force --deep --sign - --timestamp=none "$APP_DIR" >/dev/null
    echo "Signing identity '$SIGN_IDENTITY' not found; signed ad-hoc" >&2
fi

echo "$APP_DIR"
