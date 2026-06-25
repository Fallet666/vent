#!/bin/bash
set -euo pipefail

cd /Users/born-in-void/mac_fan_control/gui/VentGUI

rm -rf .build
swift build -c release 2>&1

SOURCES=$(find Sources/VentGUI -name "*.swift" | grep -v "^Sources/VentGUI/Resources/" | tr '\n' ' ')
TEST_FILE=Tests/VentGUITests/VentGUITests.swift

echo "Compiling tests..."
xcrun swiftc -strict-concurrency=complete \
    -target arm64-apple-macosx14.0 \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -F $(xcrun --show-sdk-path --sdk macosx)/System/Library/Frameworks \
    $SOURCES \
    $TEST_FILE \
    -o .build/release/VentGUITests 2>&1

echo "Running tests..."
.build/release/VentGUITests
