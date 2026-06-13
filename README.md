# Mac Fan Control

Small macOS fan-control utility with a root daemon, CLI, and menu-bar GUI.

The project is aimed at modern MacBooks, including Apple Silicon machines where direct SMC writes require a privileged daemon.

## Features

- Menu-bar app with three exclusive modes: `Auto`, `Manual RPM`, and `Auto Temp`.
- Controls all detected fans; no hardcoded fan count.
- Uses SMC fan min/max RPM ranges instead of fixed slider limits.
- Shows average temperature from available SMC temperature sensors.
- Root launchd daemon keeps fan settings active while the GUI is closed.
- CLI for reading/writing SMC keys, listing fans/sensors, and daemon control.

## Build

```bash
cmake -S . -B build
cmake --build build

cd gui/FanControlGUI
swift build -c release
```

## Install

Download the latest DMG from GitHub Releases, open it, and drag `FanControl.app` to `Applications`.

Then open `FanControl.app` from Applications and click `Install / Update` in the menu-bar popover. macOS will ask for an administrator password because the privileged daemon lives in `/Library/LaunchDaemons` and writes to `/usr/local/bin`.

The app is ad-hoc signed but not Apple-notarized yet. If macOS blocks it, right-click `FanControl.app` and choose `Open`. If Finder says the app is damaged after downloading, remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/FanControl.app
```

For local development, build and install the app bundle manually:

```bash
sudo ./install.sh
open /Applications/FanControl.app
```

To build a distributable DMG locally:

```bash
./package_dmg.sh
open dist/FanControl-*.dmg
```

The installer:

- Builds C++ binaries and the Swift GUI.
- Installs `fanctl` and `fanctld` into `/usr/local/bin`.
- Creates `/Applications/FanControl.app`.
- Bundles `fanctl` and `fanctld` inside the app for future GUI-driven daemon updates.
- Installs the daemon as `/Library/LaunchDaemons/com.fanctl.daemon.plist`.
- Writes daemon logs to `/var/log/fanctl.log` and `/var/log/fanctl.err`.

## GUI Modes

- `Auto`: returns fans to macOS/SMC automatic control.
- `Manual RPM`: sets fan RPM manually, either all fans together or separately.
- `Auto Temp`: daemon targets a desired notebook temperature and adjusts RPM automatically.

The daemon exposes runtime config through its socket protocol, so the GUI receives temperature limits from the daemon instead of duplicating hardcoded values.

## CLI Examples

```bash
./build/fanctl list
./build/fanctl temps
./build/fanctl read F0Ac
./build/fanctl persist-all 2500
./build/fanctl unpersist-all
./build/fanctl daemon status
```

Direct SMC writes usually require root:

```bash
sudo ./build/fanctl write F0Tg 2500
```

Prefer daemon-backed commands for normal use because the daemon runs as root and reconciles settings continuously.

## Daemon Protocol

The daemon listens on `/tmp/fanctl.sock` by default.

Supported commands include:

- `FANS`
- `TEMPS`
- `CONFIG`
- `MODE AUTO`
- `MODE MANUAL`
- `MODE TEMP <targetC>`
- `MODESTATUS`
- `SET <fanIndex> <rpm>`
- `SETALL <rpm>`
- `AUTO <fanIndex>`
- `AUTOALL`
- `HEARTBEAT`

The Swift GUI can override the socket path with `FANCTL_SOCKET_PATH`.

## Tests And CI

Run local non-root unit tests:

```bash
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

GitHub Actions runs the C++ build, C++ unit tests, and Swift GUI build on macOS. Pushing a tag like `v1.0.0` builds a DMG and publishes it to GitHub Releases.

## Diagnostics

Check daemon logs:

```bash
tail -f /var/log/fanctl.err
```

Check daemon socket manually:

```bash
printf 'FANS\n' | nc -U /tmp/fanctl.sock
printf 'TEMPS\n' | nc -U /tmp/fanctl.sock
```

## Notes

- Fan control behavior differs across Mac models and macOS versions.
- The backend detects capabilities from SMC keys where possible, instead of relying on a hardcoded model list.
- Some temperature keys can report misleading low values; the daemon filters known suspicious sensor families and invalid ranges.
- Apple can change SMC behavior in macOS updates, so keep `Auto` mode available as the safe fallback.
