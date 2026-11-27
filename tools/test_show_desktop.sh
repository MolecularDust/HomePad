#!/bin/bash
# Compile the production controller unchanged against a simulated Accessibility boundary.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
cp tools/tests/show_desktop.swift "$TEST_DIR/main.swift"
swiftc -swift-version 5 Sources/HomePad/ShowDesktop.swift "$TEST_DIR/main.swift" -o "$TEST_DIR/check"
"$TEST_DIR/check"
