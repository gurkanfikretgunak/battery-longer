#!/usr/bin/env bash
# Builds BatteryLonger.app from the Swift package (no Xcode required, CLT is enough).
#
#   Scripts/build_app.sh                 # release build → dist/Battery Longer.app
#   VERSION=1.2.0 Scripts/build_app.sh   # override marketing version
#   SIGN_IDENTITY="Developer ID Application: …" Scripts/build_app.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Battery Longer"
EXECUTABLE="BatteryLonger"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
CONFIG="${CONFIG:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc

DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"

step() { printf '\n\033[1;32m▶ %s\033[0m\n' "$*"; }

step "Compiling ($CONFIG)"
swift build -c "$CONFIG" 2>&1 | grep -v "org.swift.swiftpm" || true
BIN="$(swift build -c "$CONFIG" --show-bin-path 2>/dev/null | tail -1)/$EXECUTABLE"
[[ -x "$BIN" ]] || { echo "Binary not found at $BIN" >&2; exit 1; }

step "Assembling bundle"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/$EXECUTABLE"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" \
    "$ROOT/Packaging/Info.plist" > "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"
cp -R "$ROOT/Resources/." "$CONTENTS/Resources/"

step "Rendering AppIcon.icns"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
SRC_ICON="$ROOT/Packaging/AppIcon-1024.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

step "Signing ($SIGN_IDENTITY)"
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP" 2>&1 | grep -v "replacing existing signature" || true
codesign --verify --verbose=1 "$APP"

step "Done"
du -sh "$APP" | awk '{print $1}' | xargs -I{} echo "  $APP  ({})"
echo "  open \"$APP\""
