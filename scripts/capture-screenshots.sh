#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vent-capture.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$ROOT/docs/images" "$ROOT/build/documentation-module-cache" "$WORK/images" "$WORK/VentCapture.app/Contents/MacOS"
cp "$ROOT"/gui/VentGUI/Sources/VentGUI/*.swift "$WORK/"
cp "$ROOT/scripts/capture-screenshots.swift" "$WORK/CaptureScreenshots.swift"
cat > "$WORK/VentCapture.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>dev.vent.documentation-capture</string><key>CFBundleExecutable</key><string>VentCapture</string></dict></plist>
PLIST
xcrun swiftc -sdk "${SDKROOT:-$(xcrun --show-sdk-path)}" -parse-as-library -module-cache-path "$ROOT/build/documentation-module-cache" \
    "$WORK"/*.swift \
    -o "$WORK/VentCapture.app/Contents/MacOS/VentCapture"
VENT_SOCKET_PATH="$WORK/no-helper.sock" \
    "$WORK/VentCapture.app/Contents/MacOS/VentCapture" "$WORK/images" \
    -loudFanNotificationEnabled NO -checkForUpdatesAutomatically NO

# Publish only a complete set after every render succeeds.
cp "$WORK"/images/*.png "$ROOT/docs/images/"
