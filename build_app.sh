#!/bin/bash
# Builds "SpotlightPlus.app" into ./build. Needs Xcode or the Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

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

# Ad-hoc signature so macOS will run it locally.
codesign --force --deep --sign - "$APP"

echo
echo "Built: $(pwd)/$APP"
echo "Move it to /Applications and open it. Default shortcut: Option-Space."
