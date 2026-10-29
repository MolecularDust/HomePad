#!/bin/bash
# Builds "HomePad.app" into ./build. Needs Xcode or the Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")"

# Record the real SDK in the binary. SwiftPM stamps the deployment target (13.0) as the SDK, and macOS then draws
# the app in its older compatibility look: smaller traffic lights, older window shapes and controls.
SDK_VERSION="$(xcrun --show-sdk-version)"
# UNIVERSAL=1 builds for both Apple silicon and Intel Macs (tools/make_release.sh does this); otherwise only for
# this Mac, which is quicker.
ARCHS=()
[[ "${UNIVERSAL:-}" == 1 ]] && ARCHS=(--arch arm64 --arch x86_64)
LINK=(-Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker "$SDK_VERSION")
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} "${LINK[@]}"
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/HomePad"

APP="build/HomePad.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/HomePad"
# The icon, made from Resources/AppIcon.svg (see README: rebuilding the icon).
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Run by the menu-bar menu's Uninstall HomePad… (and usable on its own: see the script).
cp Resources/uninstall.sh "$APP/Contents/Resources/uninstall.sh"
# The translations (tools/localize.py writes them from tools/translations).
for lproj in Resources/*.lproj; do cp -R "$lproj" "$APP/Contents/Resources/"; done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key> <string>en</string>
    <key>CFBundleExecutable</key>        <string>HomePad</string>
    <key>CFBundleIdentifier</key>        <string>local.mike.HomePad</string>
    <key>CFBundleName</key>              <string>HomePad</string>
    <key>CFBundleDisplayName</key>       <string>HomePad</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSHighResolutionCapable</key>   <true/>
    <key>NSAppleEventsUsageDescription</key><string>HomePad asks Finder to empty the Trash, as the Dock does.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS will run it locally. The explicit requirement ties the Accessibility and Screen
# Recording permissions to the bundle id; the default (a hash of the binary) changes on every build, which
# leaves System Settings showing "on" for an older build while macOS refuses the new one.
REQ="$(mktemp)"
echo 'designated => identifier "local.mike.HomePad"' > "$REQ"
codesign --force --deep --sign - -r "$REQ" "$APP"
rm -f "$REQ"

echo
echo "Built: $(pwd)/$APP"
echo "Move it to /Applications and open it. Default shortcut: Option-Space."
