#!/usr/bin/env bash
# Packages dist/Battery Longer.app into a drag-to-install DMG with the sketch background.
#
#   Scripts/build_app.sh && Scripts/make_dmg.sh
#   → dist/BatteryLonger-<version>.dmg
#
# The install "story" inside the DMG:
#   ┌───────────────────────────────────────────────┐
#   │  [App icon]   ── sketched arrow ──▶  [Applications]  │
#   └───────────────────────────────────────────────┘
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Battery Longer"
VOL_NAME="Battery Longer"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "Run Scripts/build_app.sh first ($APP missing)" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST/BatteryLonger-$VERSION.dmg"
RW_DMG="$DIST/.rw-$VERSION.dmg"

# Finder window geometry (points). Background art is 3:2, so 660x440 keeps it undistorted.
WIN_W=660; WIN_H=440
ICON_SIZE=128
APP_X=165;  APP_Y=215
APPS_X=495; APPS_Y=215

step() { printf '\n\033[1;32m▶ %s\033[0m\n' "$*"; }

step "Staging"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"

# 1x + 2x background → single multi-resolution TIFF so Retina Finder windows stay crisp.
BG1="$STAGE/.background/bg1x.png"
BG2="$STAGE/.background/bg2x.png"
sips -z "$WIN_H" "$WIN_W" "$ROOT/Packaging/dmg-background.png" --out "$BG1" >/dev/null
sips -z $((WIN_H * 2)) $((WIN_W * 2)) "$ROOT/Packaging/dmg-background.png" --out "$BG2" >/dev/null
if tiffutil -cathidpicheck "$BG1" "$BG2" -out "$STAGE/.background/background.tiff" 2>/dev/null; then
  BG_FILE="background.tiff"
  rm -f "$BG1" "$BG2"
else
  mv "$BG1" "$STAGE/.background/background.png"; rm -f "$BG2"
  BG_FILE="background.png"
fi
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"

step "Creating writable image"
rm -f "$RW_DMG" "$DMG"
hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOL_NAME" -fs HFS+ -format UDRW -ov "$RW_DMG"
rm -rf "$STAGE"

step "Mounting"
MOUNT_DIR="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | grep -E '/Volumes/' | sed 's/.*\/Volumes\//\/Volumes\//')"
trap 'hdiutil detach -quiet "$MOUNT_DIR" 2>/dev/null || true' EXIT
echo "  $MOUNT_DIR"

if command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$MOUNT_DIR" || true
fi

step "Arranging Finder window"
# Two strategies:
#   python  – writes .DS_Store directly (deterministic, no permission prompts; needs pip once)
#   finder  – drives Finder via AppleScript (needs Automation permission for your terminal)
# LAYOUT=auto (default) tries python first, then finder.
LAYOUT="${LAYOUT:-auto}"

layout_with_python() {
  command -v python3 >/dev/null 2>&1 || return 1
  local venv="$DIST/.dmg-tools"
  if [[ ! -x "$venv/bin/python" ]]; then
    echo "  preparing python venv for .DS_Store writer (one-time)"
    python3 -m venv "$venv" >/dev/null 2>&1 || return 1
    "$venv/bin/pip" install -q ds_store mac_alias >/dev/null 2>&1 || return 1
  fi
  "$venv/bin/python" "$ROOT/Scripts/dmg_layout.py" "$MOUNT_DIR" "$APP_NAME.app" ".background/$BG_FILE" \
      "$WIN_W" "$WIN_H" "$ICON_SIZE" "$APP_X" "$APP_Y" "$APPS_X" "$APPS_Y"
}

layout_with_finder() {
osascript <<EOF
with timeout of 60 seconds
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, $((200 + WIN_W)), $((120 + WIN_H))}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to $ICON_SIZE
    set text size of theViewOptions to 13
    set background picture of theViewOptions to file ".background:$BG_FILE"
    set position of item "$APP_NAME.app" of container window to {$APP_X, $APP_Y}
    set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
end timeout
EOF
}

LAYOUT_OK=0
case "$LAYOUT" in
  finder) layout_with_finder && LAYOUT_OK=1 ;;
  python) layout_with_python && LAYOUT_OK=1 ;;
  *)      { layout_with_python || layout_with_finder; } && LAYOUT_OK=1 ;;
esac
if [[ $LAYOUT_OK -eq 0 ]]; then
  echo "  (layout skipped – the DMG still works, just without the arranged window)"
fi

sync
step "Compressing"
hdiutil detach -quiet "$MOUNT_DIR"
trap - EXIT
hdiutil convert -quiet "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW_DMG"

step "Done"
du -sh "$DMG" | awk '{print "  " $2 "  (" $1 ")"}'
echo "  open \"$DMG\""
