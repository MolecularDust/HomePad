#!/bin/bash
# Makes dist/HomePad.zip to share with friends: HomePad.app (for Apple silicon and Intel Macs) plus the install
# guide, in a folder called HomePad. Usage: tools/make_release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 ./build_app.sh

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir "$STAGE/HomePad"
# ditto keeps the app's signature and attributes intact (cp -R can break the signature).
ditto build/HomePad.app "$STAGE/HomePad/HomePad.app"
cp INSTALL.md "$STAGE/HomePad/How to install HomePad.txt"

mkdir -p dist
rm -f dist/HomePad.zip
ditto -c -k --sequesterRsrc --keepParent "$STAGE/HomePad" dist/HomePad.zip

echo
echo "Ready to share: $(pwd)/dist/HomePad.zip ($(du -h dist/HomePad.zip | cut -f1))"
