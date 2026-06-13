#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCE_DIR="$PROJECT_DIR/gui/FanControlGUI/Sources/FanControlGUI/Resources"
VERSION="${VERSION:-$(git -C "$PROJECT_DIR" describe --tags --always --dirty 2>/dev/null || echo dev)}"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/FanControl.app"
DMG_STAGING_DIR="$DIST_DIR/dmg"
DMG_PATH="$DIST_DIR/FanControl-$VERSION.dmg"

echo "=== Building C++ binaries ==="
cmake -S "$PROJECT_DIR" -B "$PROJECT_DIR/build" -DBUILD_TESTING=ON
cmake --build "$PROJECT_DIR/build" --parallel

echo ""
echo "=== Running tests ==="
ctest --test-dir "$PROJECT_DIR/build" --output-on-failure

echo ""
echo "=== Building GUI app ==="
cd "$PROJECT_DIR/gui/FanControlGUI"
swift build -c release
cd "$PROJECT_DIR"

echo ""
echo "=== Creating app bundle ==="
rm -rf "$APP_DIR" "$DMG_STAGING_DIR" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FanControlGUI</string>
    <key>CFBundleIdentifier</key>
    <string>dev.borninvoid.macfancontrol</string>
    <key>CFBundleName</key>
    <string>FanControl</string>
    <key>CFBundleDisplayName</key>
    <string>FanControl</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>MacFanControl.icns</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "$PROJECT_DIR/gui/FanControlGUI/.build/release/FanControlGUI" "$APP_DIR/Contents/MacOS/FanControlGUI"
cp "$RESOURCE_DIR/MacFanControl.icns" "$APP_DIR/Contents/Resources/MacFanControl.icns"
cp "$RESOURCE_DIR/MacFanMenuBarTemplate.png" "$APP_DIR/Contents/Resources/MacFanMenuBarTemplate.png"
cp "$RESOURCE_DIR/MacFanMenuBarTemplate@2x.png" "$APP_DIR/Contents/Resources/MacFanMenuBarTemplate@2x.png"
cp "$PROJECT_DIR/build/fanctld" "$APP_DIR/Contents/Resources/fanctld"
cp "$PROJECT_DIR/build/fanctl" "$APP_DIR/Contents/Resources/fanctl"
chmod +x "$APP_DIR/Contents/MacOS/FanControlGUI" "$APP_DIR/Contents/Resources/fanctld" "$APP_DIR/Contents/Resources/fanctl"

echo ""
echo "=== Creating DMG ==="
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/FanControl.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
    -volname "FanControl" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "=== Done ==="
echo "App: $APP_DIR"
echo "DMG: $DMG_PATH"
