#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCE_DIR="$PROJECT_DIR/gui/VentGUI/Sources/VentGUI/Resources"
APP_DIR="/Applications/Vent.app"
DAEMON_SOCKET_PATH="/tmp/ventd.sock"
DAEMON_PID_PATH="/tmp/ventd.pid"

echo "=== Building C++ binaries ==="
cmake --build "$PROJECT_DIR/build"

echo ""
echo "=== Building GUI app ==="
cd "$PROJECT_DIR/gui/VentGUI"
swift build -c release
cd "$PROJECT_DIR"

echo ""
echo "=== Creating .app bundle ==="
sudo rm -rf "$APP_DIR"
sudo mkdir -p "$APP_DIR/Contents/MacOS"
sudo mkdir -p "$APP_DIR/Contents/Resources"

sudo tee "$APP_DIR/Contents/Info.plist" > /dev/null << EOF
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
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.6</string>
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

sudo cp "$PROJECT_DIR/gui/VentGUI/.build/release/VentGUI" "$APP_DIR/Contents/MacOS/VentGUI"
sudo cp "$RESOURCE_DIR/VentApp.icns" "$APP_DIR/Contents/Resources/VentApp.icns"
sudo cp "$RESOURCE_DIR/VentMenuBarTemplate.png" "$APP_DIR/Contents/Resources/VentMenuBarTemplate.png"
sudo cp "$RESOURCE_DIR/VentMenuBarTemplate@2x.png" "$APP_DIR/Contents/Resources/VentMenuBarTemplate@2x.png"
sudo cp "$PROJECT_DIR/build/ventd" "$APP_DIR/Contents/Resources/ventd"
sudo cp "$PROJECT_DIR/build/ventctl" "$APP_DIR/Contents/Resources/ventctl"
sudo chmod +x "$APP_DIR/Contents/MacOS/VentGUI"
sudo chmod +x "$APP_DIR/Contents/Resources/ventd" "$APP_DIR/Contents/Resources/ventctl"
sudo chown -R root:wheel "$APP_DIR"

echo ""
echo "=== Installing daemon (sudo required) ==="

# Copy binaries
sudo mkdir -p /usr/local/bin
sudo cp "$PROJECT_DIR/build/ventd" /usr/local/bin/ventd
sudo cp "$PROJECT_DIR/build/ventctl" /usr/local/bin/ventctl
sudo chmod 755 /usr/local/bin/ventd /usr/local/bin/ventctl

# Kill old daemon
sudo launchctl bootout system/com.vent.daemon 2>/dev/null || true
sudo killall ventd 2>/dev/null || true
sudo rm -f "$DAEMON_SOCKET_PATH"
sudo rm -f "$DAEMON_PID_PATH"
sudo touch /var/log/ventd.log /var/log/ventd.err
sudo chmod 644 /var/log/ventd.log /var/log/ventd.err

# Install launchd plist
sudo tee /Library/LaunchDaemons/com.vent.daemon.plist > /dev/null << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vent.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ventd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardOutPath</key>
    <string>/var/log/ventd.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/ventd.err</string>
</dict>
</plist>
PLISTEOF
sudo chmod 644 /Library/LaunchDaemons/com.vent.daemon.plist

# Start daemon
sudo launchctl bootstrap system /Library/LaunchDaemons/com.vent.daemon.plist 2>/dev/null || \
sudo launchctl load /Library/LaunchDaemons/com.vent.daemon.plist

echo ""
echo "=== Done ==="
echo ""
echo "GUI installed: /Applications/Vent.app"
echo "CLI installed: /usr/local/bin/ventctl"
echo "Daemon installed as launchd service (starts at boot)"
echo ""
echo "Quick test:"
echo "  open /Applications/Vent.app"
echo "  ventctl persist-all 2500     # Set both fans to 2500 RPM"
echo "  ventctl list                 # Show fan status"
echo "  ventctl daemon status        # Check daemon health"
