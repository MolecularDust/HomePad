#!/bin/bash
# Makes dist/HomePad.dmg to share with friends: a disk image holding HomePad.app (Apple silicon and Intel), a shortcut
# to /Applications to drag it onto, and the install guide as plain text, named so it sorts first.
# Usage: tools/make_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 ./build_app.sh

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
# ditto keeps the app's signature and attributes intact (cp -R can break the signature).
ditto build/HomePad.app "$STAGE/HomePad.app"
ln -s /Applications "$STAGE/Applications"
# The guide without its Markdown marks, so it reads cleanly in TextEdit or Quick Look.
sed -e 's/\*\*//g' -e 's/`//g' -e 's/^> //' -e 's/^## //' -e 's/^# //' INSTALL.md > "$STAGE/READ ME FIRST - How to install HomePad.txt"

mkdir -p dist
rm -f dist/HomePad.dmg
hdiutil create -volname "HomePad" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov dist/HomePad.dmg >/dev/null

echo
echo "Ready to share: $(pwd)/dist/HomePad.dmg ($(du -h dist/HomePad.dmg | cut -f1))"
