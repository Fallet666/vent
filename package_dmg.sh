#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCE_DIR="$PROJECT_DIR/gui/VentGUI/Sources/VentGUI/Resources"
DEFAULT_VERSION="$(PROJECT_DIR="$PROJECT_DIR" python3 - <<'PY'
from pathlib import Path
import os
import re

header_path = Path(os.environ['PROJECT_DIR']) / 'include' / 'daemon_ipc.h'
header_text = header_path.read_text()
version_match = re.search(r'APP_VERSION\s*=\s*"([^"]+)"', header_text)
if not version_match:
    raise SystemExit('APP_VERSION not found')
print(version_match.group(1))
PY
)"
VERSION="${VERSION:-$DEFAULT_VERSION}"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/Vent.app"
DMG_STAGING_DIR="$DIST_DIR/dmg"
DMG_PATH="$DIST_DIR/Vent-$VERSION.dmg"

echo "=== Building C++ binaries ==="
cmake -S "$PROJECT_DIR" -B "$PROJECT_DIR/build" -DBUILD_TESTING=ON
cmake --build "$PROJECT_DIR/build" --parallel

echo ""
echo "=== Running tests ==="
ctest --test-dir "$PROJECT_DIR/build" --output-on-failure

echo ""
echo "=== Building GUI app ==="
cd "$PROJECT_DIR/gui/VentGUI"
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
    <string>VentGUI</string>
    <key>CFBundleIdentifier</key>
    <string>dev.borninvoid.macfancontrol</string>
    <key>CFBundleName</key>
    <string>Vent</string>
    <key>CFBundleDisplayName</key>
    <string>Vent</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>VentApp.icns</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "$PROJECT_DIR/gui/VentGUI/.build/release/VentGUI" "$APP_DIR/Contents/MacOS/VentGUI"
cp "$RESOURCE_DIR/VentApp.icns" "$APP_DIR/Contents/Resources/VentApp.icns"
cp "$RESOURCE_DIR/VentMenuBarTemplate.png" "$APP_DIR/Contents/Resources/VentMenuBarTemplate.png"
cp "$RESOURCE_DIR/VentMenuBarTemplate@2x.png" "$APP_DIR/Contents/Resources/VentMenuBarTemplate@2x.png"
cp "$PROJECT_DIR/build/ventd" "$APP_DIR/Contents/Resources/ventd"
cp "$PROJECT_DIR/build/ventctl" "$APP_DIR/Contents/Resources/ventctl"
chmod +x "$APP_DIR/Contents/MacOS/VentGUI" "$APP_DIR/Contents/Resources/ventd" "$APP_DIR/Contents/Resources/ventctl"

echo ""
echo "=== Signing app bundle ==="
codesign --force --sign - "$APP_DIR/Contents/MacOS/VentGUI"
codesign --force --sign - "$APP_DIR/Contents/Resources/ventd"
codesign --force --sign - "$APP_DIR/Contents/Resources/ventctl"
codesign --force --sign - --deep "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo ""
echo "=== Creating DMG ==="
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/Vent.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
    -volname "Vent" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "=== Done ==="
echo "App: $APP_DIR"
echo "DMG: $DMG_PATH"
