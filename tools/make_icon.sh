#!/bin/bash
# Rebuilds Resources/AppIcon.icns from Resources/AppIcon.svg (every size macOS uses, each drawn from the SVG).
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
swiftc -O tools/render_icon.swift -o "$WORK/render_icon"
SET="$WORK/AppIcon.iconset"
mkdir "$SET"
for s in 16 32 128 256 512; do
    "$WORK/render_icon" Resources/AppIcon.svg "$SET/icon_${s}x${s}.png" "$s"
    "$WORK/render_icon" Resources/AppIcon.svg "$SET/icon_${s}x${s}@2x.png" "$((s * 2))"
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -rf "$WORK"
echo "Made Resources/AppIcon.icns"
