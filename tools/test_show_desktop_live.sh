#!/bin/bash
# Exercise the actual SwiftUI tray button, controller and screen covers. Requires HomePad's existing Accessibility
# and Screen Recording grants. Only the two fixture PIDs and the test process are visible to window discovery.
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT_DIR="$PWD"
[ -d build/HomePad.app ] || ./build_app.sh
TEST_DIR="$(mktemp -d)"
cleanup() {
    touch "$TEST_DIR/done"
    python3 - "$TEST_DIR" <<'PY'
import sys, time
from pathlib import Path
root=Path(sys.argv[1])
deadline=time.monotonic()+5
while time.monotonic()<deadline:
    waiting=[tag for tag in ['A','B'] if (root/f'fixture-{tag}.json').exists() and not (root/f'fixture-{tag}-stopped').exists()]
    if not waiting: break
    time.sleep(.05)
PY
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT
mkdir -p "$TEST_DIR/Fixture.app/Contents/MacOS" "$TEST_DIR/HomePadProbe.app/Contents/MacOS"
python3 - "$PROJECT_DIR/build/HomePad.app/Contents/Info.plist" "$TEST_DIR" <<'PY'
import sys, plistlib
from pathlib import Path
info=plistlib.loads(Path(sys.argv[1]).read_bytes())
root=Path(sys.argv[2])
(root/'HomePadProbe.app/Contents/Info.plist').write_bytes(plistlib.dumps(info))
info.update(CFBundleIdentifier='local.mike.HomePad.AnimationFixture', CFBundleExecutable='Fixture', CFBundleName='HomePad Test Fixture')
(root/'Fixture.app/Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
TARGET="$(uname -m)-apple-macosx13.0"
swiftc -g -swift-version 5 -target "$TARGET" tools/tests/show_desktop_live/fixture.swift -o "$TEST_DIR/Fixture.app/Contents/MacOS/Fixture"
swiftc -g -swift-version 5 -target "$TARGET" Sources/HomePad/ShowDesktop.swift Sources/HomePad/DesktopTransition.swift \
    Sources/HomePad/Spaces.swift Sources/HomePad/TaskbarTray.swift tools/tests/show_desktop_live/main.swift \
    -o "$TEST_DIR/HomePadProbe.app/Contents/MacOS/HomePad"
codesign --force --sign - "$TEST_DIR/Fixture.app"
codesign --force --sign - -r='designated => identifier "local.mike.HomePad"' "$TEST_DIR/HomePadProbe.app"
open -n "$TEST_DIR/Fixture.app" --args "$TEST_DIR" A
open -n "$TEST_DIR/Fixture.app" --args "$TEST_DIR" B
open -n -W "$TEST_DIR/HomePadProbe.app" --args "$TEST_DIR"
if [ -f "$TEST_DIR/failure.txt" ]; then cat "$TEST_DIR/failure.txt"; exit 1; fi
python3 - "$TEST_DIR/results.json" <<'PY'
import sys, json
from pathlib import Path
checks=json.loads(Path(sys.argv[1]).read_text())
assert len(checks)==3
for cycle in checks:
    assert cycle['originalWindowsVisible']==10
    assert cycle['previouslyMinimizedWindowsPreserved']==2
    assert cycle['layoutWindowsVerified']==10 and cycle['geometryWindowsVerified']==10
    if cycle['shadowHandoffVerified']: assert cycle['shadowHandoffDifference'] < .025
    print(f"Cycle {cycle['cycle']}: desktop visible {cycle['desktopVisibleMilliseconds']} ms; windows visible {cycle['windowsVisibleMilliseconds']} ms; minimize settled {cycle['minimizeMilliseconds']} ms; restore settled {cycle['restoreMilliseconds']} ms")
print('PASS: real tray button, 3 full cycles; native and browser content repaint before uncovering; 10 windows restored with exact stacking order, positions and sizes; 2 pre-minimized windows preserved')
print(f"Shadow comparisons before and after handoff: {sum(c['shadowHandoffVerified'] for c in checks)}/3 (requires macOS 15.2+)")
PY
