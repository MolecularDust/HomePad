#!/bin/bash
# Builds "SpotlightPlus.app" into ./build. Needs Xcode or the Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")"

# Record the real SDK in the binary. SwiftPM stamps the deployment target (13.0) as the SDK, and macOS then draws
# the app in its older compatibility look: smaller traffic lights, older window shapes and controls.
SDK_VERSION="$(xcrun --show-sdk-version)"
swift build -c release -Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker "$SDK_VERSION"

APP="build/SpotlightPlus.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SpotlightPlus "$APP/Contents/MacOS/SpotlightPlus"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>        <string>SpotlightPlus</string>
    <key>CFBundleIdentifier</key>        <string>local.mike.SpotlightPlus</string>
    <key>CFBundleName</key>              <string>SpotlightPlus</string>
    <key>CFBundleDisplayName</key>       <string>SpotlightPlus</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS will run it locally. The explicit requirement ties the Accessibility and Screen
# Recording permissions to the bundle id; the default (a hash of the binary) changes on every build, which
# leaves System Settings showing "on" for an older build while macOS refuses the new one.
REQ="$(mktemp)"
echo 'designated => identifier "local.mike.SpotlightPlus"' > "$REQ"
codesign --force --deep --sign - -r "$REQ" "$APP"
rm -f "$REQ"

echo
echo "Built: $(pwd)/$APP"
echo "Move it to /Applications and open it. Default shortcut: Option-Space."
