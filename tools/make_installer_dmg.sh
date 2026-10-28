#!/bin/bash
# Makes dist/HomePad-Installer.dmg: a disk image holding the installer (tools/make_pkg.sh), whose window shows the
# steps to get past the "can't be opened" block (picture: tools/render_dmg_background.swift).
#
# Why a disk image around the installer: macOS blocks the unsigned installer before it can show anything, and a script
# would be blocked the same way. Opening a disk image isn't blocked, so its window can explain the steps first.
#
# Laying out the window goes through Finder, so the first run asks to let Terminal (or whatever runs this) control
# Finder, and a Finder window opens for a few seconds. Usage: tools/make_installer_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VOLUME="Install HomePad"
OUT=dist/HomePad-Installer.dmg
if [ -e "/Volumes/$VOLUME" ]; then
    echo "Eject the disk named \"$VOLUME\" first (Finder sidebar), then run this again." >&2
    exit 1
fi

tools/make_pkg.sh

WORK="$(mktemp -d)"
MOUNT=""
cleanup() {
    [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

# The window picture, sharp on Retina screens: one TIFF holding the 1x and 2x images.
swiftc -O tools/render_dmg_background.swift -o "$WORK/render_bg" 2>/dev/null
mkdir -p "$WORK/stage/.background"
"$WORK/render_bg" "$WORK/bg.png" 1
"$WORK/render_bg" "$WORK/bg@2x.png" 2
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/stage/.background/steps.tiff" 2>/dev/null
cp dist/HomePad.pkg "$WORK/stage/Install HomePad.pkg"

# A writable image first, so Finder can save the window's look (its .DS_Store) on it; compressed afterwards.
hdiutil create -volname "$VOLUME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -size 60m "$WORK/rw.dmg" >/dev/null
MOUNT="$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen | awk -F'\t' '/\/Volumes\// {print $NF}')"

# Window 660 × 470 points inside, like the picture (the title bar adds 28); icon positions are its centre, from the top left.
osascript <<OSA
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 618}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 13
        set background picture of opts to file ".background:steps.tiff"
        set position of item "Install HomePad.pkg" of container window to {130, 230}
        update without registering applications
        delay 1
        close
    end tell
end tell
OSA

# Finder writes .DS_Store a moment after the window closes.
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$MOUNT/.DS_Store" ] && break; sleep 0.5; done
[ -f "$MOUNT/.DS_Store" ] || { echo "Finder didn't save the window layout." >&2; exit 1; }
rm -rf "$MOUNT/.fseventsd"
sync
hdiutil detach "$MOUNT" -quiet
MOUNT=""

mkdir -p dist
rm -f "$OUT"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null

echo
echo "Ready to share: $(pwd)/$OUT ($(du -h "$OUT" | cut -f1))"
