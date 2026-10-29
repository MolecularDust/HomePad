#!/bin/bash
# Pictures of HomePad's windows in a language, for checking translations and right-to-left layouts:
#     tools/snapshot.sh ar [out-folder]     (default out-folder: build/snapshots/<lang>)
# Builds a debug copy of the app next to build/HomePad.app, quits a running HomePad (it is restarted from
# build/HomePad.app afterwards), and runs the copy once with that language. Nothing is changed in HomePad's settings.
set -euo pipefail
cd "$(dirname "$0")/.."
LANG_CODE="${1:?usage: tools/snapshot.sh <language code> [out-folder]}"
OUT="${2:-build/snapshots/$LANG_CODE}"
[ -d build/HomePad.app ] || ./build_app.sh
swift build >/dev/null
rm -rf build/Snapshot.app && cp -R build/HomePad.app build/Snapshot.app
cp .build/debug/HomePad build/Snapshot.app/Contents/MacOS/HomePad
codesign --force --sign - build/Snapshot.app 2>/dev/null
mkdir -p "$OUT" && rm -f "$OUT"/*.png
WAS_RUNNING=0
for pid in $(pgrep -x HomePad || true); do WAS_RUNNING=1; kill "$pid"; while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done; done
# The reading direction too, as choosing the language in HomePad sets it (Localization.choose).
case "$LANG_CODE" in ar|fa) RTL=YES ;; *) RTL=NO ;; esac
build/Snapshot.app/Contents/MacOS/HomePad -AppleLanguages "($LANG_CODE)" -AppleTextDirection YES \
    -NSForceRightToLeftWritingDirection $RTL -HomePadSnapshotDir "$(cd "$OUT" && pwd)" >/dev/null 2>&1 || true
if [ "$WAS_RUNNING" = 1 ]; then open build/HomePad.app; fi
ls "$OUT"
