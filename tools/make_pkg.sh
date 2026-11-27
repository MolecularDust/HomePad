#!/bin/bash
# Makes dist/HomePad.pkg to share with friends: an installer wizard (Welcome, What to expect, Install, Done) that puts
# HomePad.app (Apple silicon and Intel) in /Applications and opens it. Wizard text: tools/pkg/text/<code>.json (tools/pkg/make_pages.py);
# scripts: tools/pkg/scripts. Usage: tools/make_pkg.sh
#
# The package is not signed (that takes an Apple Developer ID), so macOS blocks it once, before the wizard opens.
# Apps installed by Installer are not marked "downloaded from the internet", so HomePad itself opens without a block.
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 ./build_app.sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/root"
# ditto keeps the app's signature and attributes intact (cp -R can break the signature).
ditto build/HomePad.app "$WORK/root/HomePad.app"

# Not relocatable: otherwise Installer would update a copy of HomePad it finds somewhere else (a build folder, say)
# instead of the one in /Applications.
pkgbuild --analyze --root "$WORK/root" "$WORK/components.plist" >/dev/null
python3 - "$WORK/components.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
components = plistlib.load(open(p, "rb"))
for c in components:
    c["BundleIsRelocatable"] = False
    c["BundleOverwriteAction"] = "upgrade"
plistlib.dump(components, open(p, "wb"))
PY

pkgbuild --root "$WORK/root" --component-plist "$WORK/components.plist" --install-location /Applications \
         --identifier local.mike.HomePad --version 1.1 --ownership recommended \
         --scripts tools/pkg/scripts "$WORK/HomePad-component.pkg" >/dev/null

# The wizard's pages in every language (tools/pkg/text/<code>.json), each with style.css written into it: productbuild
# only takes the files the distribution names, so a linked stylesheet would be left out. Installer shows the language
# of the Mac (it has no language menu of its own), English when it has no match.
mkdir "$WORK/resources"
python3 tools/pkg/make_pages.py "$WORK/resources"

mkdir -p dist
rm -f dist/HomePad.pkg
productbuild --distribution tools/pkg/distribution.xml --resources "$WORK/resources" \
             --package-path "$WORK" dist/HomePad.pkg >/dev/null

echo
echo "Ready to share: $(pwd)/dist/HomePad.pkg ($(du -h dist/HomePad.pkg | cut -f1))"
