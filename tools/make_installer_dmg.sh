#!/bin/bash
# Makes the installer disk image: the installer (tools/make_pkg.sh) in a window that shows the steps to get past the
# "can't be opened" block (picture: tools/render_dmg_background.swift).
#
#     tools/make_installer_dmg.sh          English: dist/HomePad-Installer.dmg
#     tools/make_installer_dmg.sh ru       Russian: dist/ru/HomePad-Installer.dmg
#     tools/make_installer_dmg.sh all      every language in tools/pkg/text (English as above, the others in dist/<code>)
#
# The window's text and names come from tools/pkg/text/<code>.json (the d_* keys). The installer inside is the same
# for every language: Installer itself shows its pages in the Mac's language. Every copy is called
# HomePad-Installer.dmg, the name the installer's Trash warning looks for.
#
# Why a disk image around the installer: macOS blocks the unsigned installer before it can show anything, and a script
# would be blocked the same way. Opening a disk image isn't blocked, so its window can explain the steps first.
#
# Laying out the window goes through Finder, so the first run asks to let Terminal (or whatever runs this) control
# Finder, and a Finder window opens for a few seconds per language.
set -euo pipefail
cd "$(dirname "$0")/.."

CHOICE="${1:-en}"
if [ "$CHOICE" = all ]; then
    CODES=$(ls tools/pkg/text | sed 's/\.json$//')
else
    [ -f "tools/pkg/text/$CHOICE.json" ] || { echo "No tools/pkg/text/$CHOICE.json" >&2; exit 1; }
    CODES="$CHOICE"
fi

tools/make_pkg.sh

WORK="$(mktemp -d)"
MOUNT=""
cleanup() {
    [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

swiftc -O tools/render_dmg_background.swift -o "$WORK/render_bg" 2>/dev/null
swiftc -O tools/render_dmg_icons.swift -o "$WORK/render_icons" 2>/dev/null
ICON_SIZE=112
# The installer gets the classic brown box with the yellow cube, which people know from other installers. Newer macOS
# draws packages with a blue icon instead, but Installer still ships the classic one.
BOX=/System/Library/CoreServices/Installer.app/Contents/Resources/package.icns

text() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$1" "$2"; }

build() {
    local code="$1" json="tools/pkg/text/$1.json" rtl=0
    case "$code" in ar|fa) rtl=1 ;; esac
    local volume pkg shortcut tile out
    volume="$(text "$json" d_pkg)"
    pkg="$volume.pkg"
    shortcut="$(text "$json" d_tile_name)"
    tile="$(text "$json" d_tile)"
    if [ "$code" = en ]; then out=dist/HomePad-Installer.dmg; else out="dist/$code/HomePad-Installer.dmg"; fi
    if [ -e "/Volumes/$volume" ]; then
        echo "Eject the disk named \"$volume\" first (Finder sidebar), then run this again." >&2
        exit 1
    fi

    # The window picture, sharp on Retina screens: one TIFF holding the 1x and 2x images. Its layout says where the
    # two icons go and how tall the window is.
    rm -rf "$WORK/stage" "$WORK/rw.dmg"
    mkdir -p "$WORK/stage/.background"
    "$WORK/render_bg" "$WORK/bg.png" 1 "$json" "$WORK/layout.sh" "$rtl"
    "$WORK/render_bg" "$WORK/bg@2x.png" 2 "$json" "$WORK/layout.sh" "$rtl"
    tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/stage/.background/steps.tiff" 2>/dev/null
    # shellcheck disable=SC1091
    . "$WORK/layout.sh"
    cp dist/HomePad.pkg "$WORK/stage/$pkg"

    # A writable image first, so Finder can save the window's look (its .DS_Store) on it; compressed afterwards.
    hdiutil create -volname "$volume" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -size 60m "$WORK/rw.dmg" >/dev/null
    MOUNT="$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen | awk -F'\t' '/\/Volumes\// {print $NF}')"

    # The blue tile: a shortcut to the Privacy & Security page of System Settings (where Open Anyway is). It leads to a
    # file macOS ships with, not to anything downloaded, so it opens without a block. A Finder alias rather than a
    # symbolic link, so it can carry its own picture (tools/render_dmg_icons.swift). Names go to AppleScript as
    # arguments, so no translation can break the script.
    osascript - "$MOUNT" "$shortcut" >/dev/null <<'OSA'
on run argv
    tell application "Finder" to make new alias file at (POSIX file (item 1 of argv) as alias) ¬
        to (POSIX file "/System/Library/PreferencePanes/Security.prefPane" as alias) with properties {name:(item 2 of argv)}
end run
OSA
    "$WORK/render_icons" "$MOUNT/$shortcut" "$ICON_SIZE" "$tile"
    if [ -f "$BOX" ]; then "$WORK/render_icons" "$MOUNT/$pkg" --from "$BOX"; fi

    # The window is 660 points wide and H tall inside, like the picture (the title bar adds 28); icon positions are
    # their centres, from the top left.
    osascript - "$volume" "$pkg" "$shortcut" "$ICON_SIZE" "$((80 + H + 28))" "$PKG_X" "$PKG_Y" "$TILE_X" "$TILE_Y" <<'OSA'
on run argv
    tell application "Finder"
        tell disk (item 1 of argv)
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 80, 860, (item 5 of argv) as integer}
            set opts to the icon view options of container window
            set arrangement of opts to not arranged
            set icon size of opts to (item 4 of argv) as integer
            set text size of opts to 13
            set background picture of opts to file ".background:steps.tiff"
            set position of item (item 2 of argv) of container window to {(item 6 of argv) as integer, (item 7 of argv) as integer}
            set position of item (item 3 of argv) of container window to {(item 8 of argv) as integer, (item 9 of argv) as integer}
            update without registering applications
            delay 1
            close
        end tell
    end tell
end run
OSA

    # Finder writes .DS_Store a moment after the window closes.
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$MOUNT/.DS_Store" ] && break; sleep 0.5; done
    [ -f "$MOUNT/.DS_Store" ] || { echo "Finder didn't save the window layout ($code)." >&2; exit 1; }
    rm -rf "$MOUNT/.fseventsd"
    sync
    hdiutil detach "$MOUNT" -quiet
    MOUNT=""

    mkdir -p "$(dirname "$out")"
    rm -f "$out"
    hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$out" >/dev/null 2>&1
    echo "Ready to share ($code): $(pwd)/$out ($(du -h "$out" | cut -f1))"
}

for code in $CODES; do build "$code"; done
