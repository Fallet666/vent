# FanControl for macOS

[![CI](https://github.com/Fallet666/mac-manual-rpm/actions/workflows/ci.yml/badge.svg)](https://github.com/Fallet666/mac-manual-rpm/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/Fallet666/mac-manual-rpm)](https://github.com/Fallet666/mac-manual-rpm/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A free, open-source menu-bar fan control app for MacBooks.

FanControl gives you simple manual RPM control, automatic temperature-based cooling, and a safe one-click return to macOS automatic fan management. It is built for modern macOS, including Apple Silicon Macs where fan writes require a privileged helper daemon.

[Download the latest DMG](https://github.com/Fallet666/mac-manual-rpm/releases/latest)

## Why FanControl

- Keep your MacBook cooler during heavy work, gaming, rendering, coding, or external-display use.
- Set both fans together or control each fan separately when your Mac exposes multiple fans.
- Use real fan limits reported by SMC instead of hardcoded RPM sliders.
- Run everything from the menu bar without keeping a full app window open.
- Stay in control: `Auto` mode immediately returns fan management to macOS.
- No accounts, no telemetry, no subscriptions, no paid upgrade.

## Features

- Menu-bar UI with three clear modes: `Auto`, `Manual RPM`, and `Auto Temp`.
- Automatic fan detection with no hardcoded fan count.
- Real per-device min/max RPM ranges from SMC.
- Average temperature display from available SMC sensors.
- Privileged launchd helper keeps fan settings active while the GUI is closed.
- Built-in `Install / Update` button for the helper daemon.
- Built-in `Uninstall` action for removing the privileged helper.
- Helper version display in the menu-bar popover.
- CLI for advanced users and diagnostics.
- GitHub Actions CI and release DMG builds.

## Install

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/Fallet666/mac-manual-rpm/releases/latest).
2. Open the DMG and drag `FanControl.app` to `Applications`.
3. Open `FanControl.app` and click `Install / Update` in the menu-bar popover.

macOS will ask for an administrator password because FanControl installs a privileged helper daemon into `/Library/LaunchDaemons` and command-line tools into `/usr/local/bin`.

To remove the privileged helper later, open FanControl and click `Uninstall`. The app switches fans back to `Auto`, stops the daemon, and removes installed helper binaries.

The app is ad-hoc signed but not Apple-notarized yet. If macOS blocks it, right-click `FanControl.app` and choose `Open`. If Finder says the app is damaged after downloading, remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/FanControl.app
```

## How To Use

After launching FanControl, click the fan icon in the macOS menu bar.

### Auto

Use `Auto` when you want macOS and SMC to control the fans normally. This is the safest fallback and the recommended default when you do not need manual cooling.

### Manual RPM

Use `Manual RPM` when you want a fixed fan speed.

- Turn off `Separate fans` to move all fans together.
- Turn on `Separate fans` to tune each detected fan independently.
- Sliders use the real RPM range reported by your Mac.

### Auto Temp

Use `Auto Temp` when you want to pick a target laptop temperature instead of a raw RPM value. The daemon watches available temperature sensors and adjusts fan speed automatically.

## Safety Notes

- FanControl does not disable macOS thermal protection.
- `Auto` mode is always available and returns control to macOS.
- The daemon has a watchdog for manual RPM control.
- Temperature sensors and fan behavior vary across Mac models and macOS releases.
- If anything looks wrong, switch to `Auto` or quit the app.

## Privacy

FanControl does not collect analytics, send telemetry, create accounts, or talk to external servers during normal use. The app only communicates with its local helper daemon through a Unix socket at `/tmp/fanctl.sock`.

## Compatibility

The project is designed around capability detection rather than a hardcoded Mac model list.

Known design goals:

- Apple Silicon MacBooks.
- Intel MacBooks where SMC fan keys are available.
- Any number of detected fans.
- Real SMC min/max fan limits.

Fan control behavior can differ between Mac models. If your model behaves differently, please open an issue with your Mac model, macOS version, and the output of the diagnostics commands below.

## Troubleshooting

### The app says the daemon is offline

Open the menu-bar popover and click `Install / Update`. If it still fails, check the logs:

```bash
tail -f /var/log/fanctl.err
```

### macOS says the app is damaged

This is Gatekeeper quarantine on a non-notarized build:

```bash
xattr -dr com.apple.quarantine /Applications/FanControl.app
```

Then right-click `FanControl.app` and choose `Open`.

### The menu-bar icon is hidden

macOS, Bartender, Hidden Bar, or similar utilities can hide status-bar items. Check your menu-bar overflow/hidden-items settings.

### Fans do not react immediately

Some Macs and macOS versions reconcile fan state aggressively. Keep the app in `Manual RPM` or `Auto Temp` for a few seconds and check daemon logs if the fan target does not change.

## CLI

Advanced users can use `fanctl` after installing the helper:

```bash
fanctl list
fanctl temps
fanctl daemon status
fanctl persist-all 2500
fanctl unpersist-all
fanctl read F0Ac
```

Direct SMC writes normally require root. Prefer daemon-backed commands for normal use because the daemon runs with the required privileges and keeps settings reconciled.

## Build From Source

Requirements:

- macOS
- Xcode Command Line Tools
- CMake
- Swift Package Manager

```bash
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build
ctest --test-dir build --output-on-failure

cd gui/FanControlGUI
swift build -c release
```

Build a distributable DMG locally:

```bash
./package_dmg.sh
open dist/FanControl-*.dmg
```

Install from a local build:

```bash
sudo ./install.sh
open /Applications/FanControl.app
```

## Daemon Protocol

The daemon listens on `/tmp/fanctl.sock` by default.

Supported commands include:

- `FANS`
- `TEMPS`
- `CONFIG`
- `VERSION`
- `MODE AUTO`
- `MODE MANUAL`
- `MODE TEMP <targetC>`
- `MODESTATUS`
- `SET <fanIndex> <rpm>`
- `SETALL <rpm>`
- `AUTO <fanIndex>`
- `AUTOALL`
- `WRITE <key> <value>`
- `HEARTBEAT`

The Swift GUI can override the socket path with `FANCTL_SOCKET_PATH`.

## Project Status

FanControl is young but usable. The current priority is making installation, model compatibility, and safety behavior excellent before adding advanced automation.

Planned work:

- Developer ID signing and Apple notarization.
- Better first-run onboarding.
- Temperature/fan history charts.
- Per-mode presets.
- Safer model compatibility reporting.
- Automatic update checks.
- More tests around daemon protocol and temperature control.

See [`docs/LAUNCH_PLAN.md`](docs/LAUNCH_PLAN.md) for the product roadmap, Reddit launch draft, and promotion plan.

## Contributing

Issues, compatibility reports, UI feedback, and pull requests are welcome.

Please use the GitHub compatibility report template when testing a new Mac model.

Useful information for compatibility reports:

- Mac model and year.
- macOS version.
- Apple Silicon or Intel.
- Number of detected fans.
- Output of `fanctl list`, `fanctl temps`, and `fanctl daemon status`.

## License

MIT. See [`LICENSE`](LICENSE).
