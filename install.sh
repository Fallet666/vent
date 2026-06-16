#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCE_DIR="$PROJECT_DIR/gui/FanControlGUI/Sources/FanControlGUI/Resources"
APP_DIR="/Applications/FanControl.app"
DAEMON_SOCKET_PATH="/tmp/fanctl.sock"
DAEMON_PID_PATH="/tmp/fanctld.pid"

echo "=== Building C++ binaries ==="
cmake --build "$PROJECT_DIR/build"

echo ""
echo "=== Building GUI app ==="
cd "$PROJECT_DIR/gui/FanControlGUI"
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
    <string>FanControlGUI</string>
    <key>CFBundleIdentifier</key>
    <string>dev.borninvoid.macfancontrol</string>
    <key>CFBundleName</key>
    <string>FanControl</string>
    <key>CFBundleDisplayName</key>
    <string>FanControl</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.5</string>
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

sudo cp "$PROJECT_DIR/gui/FanControlGUI/.build/release/FanControlGUI" "$APP_DIR/Contents/MacOS/FanControlGUI"
sudo cp "$RESOURCE_DIR/MacFanControl.icns" "$APP_DIR/Contents/Resources/MacFanControl.icns"
sudo cp "$RESOURCE_DIR/MacFanMenuBarTemplate.png" "$APP_DIR/Contents/Resources/MacFanMenuBarTemplate.png"
sudo cp "$RESOURCE_DIR/MacFanMenuBarTemplate@2x.png" "$APP_DIR/Contents/Resources/MacFanMenuBarTemplate@2x.png"
sudo cp "$PROJECT_DIR/build/fanctld" "$APP_DIR/Contents/Resources/fanctld"
sudo cp "$PROJECT_DIR/build/fanctl" "$APP_DIR/Contents/Resources/fanctl"
sudo chmod +x "$APP_DIR/Contents/MacOS/FanControlGUI"
sudo chmod +x "$APP_DIR/Contents/Resources/fanctld" "$APP_DIR/Contents/Resources/fanctl"
sudo chown -R root:wheel "$APP_DIR"

echo ""
echo "=== Installing daemon (sudo required) ==="

# Copy binaries
sudo mkdir -p /usr/local/bin
sudo cp "$PROJECT_DIR/build/fanctld" /usr/local/bin/fanctld
sudo cp "$PROJECT_DIR/build/fanctl" /usr/local/bin/fanctl
sudo chmod 755 /usr/local/bin/fanctld /usr/local/bin/fanctl

# Kill old daemon
sudo launchctl bootout system/com.fanctl.daemon 2>/dev/null || true
sudo killall fanctld 2>/dev/null || true
sudo rm -f "$DAEMON_SOCKET_PATH"
sudo rm -f "$DAEMON_PID_PATH"
sudo touch /var/log/fanctl.log /var/log/fanctl.err
sudo chmod 644 /var/log/fanctl.log /var/log/fanctl.err

# Install launchd plist
sudo tee /Library/LaunchDaemons/com.fanctl.daemon.plist > /dev/null << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fanctl.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/fanctld</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardOutPath</key>
    <string>/var/log/fanctl.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/fanctl.err</string>
</dict>
</plist>
PLISTEOF
sudo chmod 644 /Library/LaunchDaemons/com.fanctl.daemon.plist

# Start daemon
sudo launchctl bootstrap system /Library/LaunchDaemons/com.fanctl.daemon.plist 2>/dev/null || \
sudo launchctl load /Library/LaunchDaemons/com.fanctl.daemon.plist

echo ""
echo "=== Done ==="
echo ""
echo "GUI installed: /Applications/FanControl.app"
echo "CLI installed: /usr/local/bin/fanctl"
echo "Daemon installed as launchd service (starts at boot)"
echo ""
echo "Quick test:"
echo "  open /Applications/FanControl.app"
echo "  fanctl persist-all 2500     # Set both fans to 2500 RPM"
echo "  fanctl list                 # Show fan status"
echo "  fanctl daemon status        # Check daemon health"
