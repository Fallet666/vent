<h1 align="center">Vent</h1>

<p align="center">
  <em>Lightweight fan control for macOS</em>
</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&logo=github" alt="Release"></a>
  <a href="https://github.com/Fallet666/vent/releases"><img src="https://img.shields.io/github/downloads/Fallet666/vent/total?style=flat-square&logo=github" alt="Downloads"></a>
  <a href="https://github.com/Fallet666/vent/actions/workflows/ci.yml"><img src="https://github.com/Fallet666/vent/actions/workflows/ci.yml/badge.svg?style=flat-square" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-12+-black?style=flat-square&logo=apple" alt="macOS 12+">
  <img src="https://img.shields.io/badge/Apple%20Silicon-✓-brightgreen?style=flat-square&logo=apple" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Intel-✓-brightgreen?style=flat-square&logo=intel" alt="Intel">
</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest">
    <img src="https://img.shields.io/badge/⬇_Download_Vent-0066CC?style=for-the-badge" alt="Download">
  </a>
  &nbsp;
  <a href="https://github.com/Fallet666/homebrew-tap">
    <img src="https://img.shields.io/badge/brew_install_--cask_vent-F5492B?style=for-the-badge&logo=homebrew" alt="brew install --cask vent">
  </a>
</p>

---

Menu-bar fan control for macOS. Manual RPM, temperature target, or automatic — from a compact popover. No accounts, no telemetry, no Dock icon.

Built with Swift + C++17. Works on Apple Silicon and Intel. A privileged helper daemon (`ventd`) handles SMC writes and keeps fan settings running after the app is closed.

---

## Features

| | |
|---|---|
| **Three modes** | Auto (OS default), Manual RPM, Auto Temp — switch instantly |
| **Per-fan control** | Adjust all fans in unison or each one independently |
| **Real SMC ranges** | Sliders use your Mac's actual min/max RPM limits |
| **Persistent daemon** | Settings survive app quit via a launchd helper |
| **Profiles** | Quiet, Normal, Gaming, Lap presets — or save your own |
| **CLI tool** | `ventctl` for scripting and remote control |
| **Universal** | Apple Silicon + Intel, macOS 12+ |

---

## Install

### Homebrew

```bash
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### DMG

Download from [Releases](https://github.com/Fallet666/vent/releases/latest), drag to Applications, launch, and click **Install Helper** in settings.

The helper installs into `/Library/LaunchDaemons` and CLI tools into `/usr/local/bin`. macOS will ask for an admin password.

> The app is ad-hoc signed. If macOS blocks it, right-click → **Open**, or:
> ```bash
> xattr -dr com.apple.quarantine /Applications/Vent.app
> ```

---

## Usage

Click the fan icon in the menu bar.

- **Auto** — macOS controls fans normally. The safe default.
- **Manual RPM** — set a fixed speed with sliders. Toggle "Separate fans" for per-fan control.
- **Auto Temp** — pick a target temperature (°C). The daemon ramps fans to maintain it.
- **Profiles** — tap a preset (Quiet, Normal, Gaming, Lap) or save your own configuration.

Fan settings persist after the app closes. Switch back to **Auto** or quit Vent to return to macOS defaults.

---

## CLI

`ventctl` is installed alongside the helper:

```bash
ventctl list              # list fans with RPM ranges
ventctl temps             # show all temperature sensors
ventctl daemon status     # check mode, target temp, override map
ventctl persist-all 2500  # set and persist fan speed
ventctl unpersist-all     # return to macOS auto control
ventctl read F0Ac         # read a raw SMC key
```

---

## Build From Source

Requirements: macOS, Xcode CLI Tools, CMake, SwiftPM.

```bash
# Daemon
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(sysctl -n hw.ncpu)
ctest --test-dir build --output-on-failure

# GUI
cd gui/VentGUI
swift build -c release

# Package DMG
./package_dmg.sh
```

---

## Architecture

```
Vent.app (SwiftUI menu-bar app)
  │
  ├── VentGUI — popover UI, fan sliders, profiles
  ├── DaemonClient — AF_UNIX socket IPC to ventd
  └── NativeSlider — NSSlider wrapper (AppKit)
          │
          ▼  /tmp/ventd.sock
ventd (C++17 daemon, runs as root via launchd)
  ├── IntelSMCBackend — IOKit SMC reads/writes
  ├── HID temperature sensors (Apple Silicon)
  ├── Auto-temp control loop (2s interval)
  ├── Reconciliation loop (300ms, on-change only)
  └── Watchdog — reverts to Auto on client disconnect

ventctl (CLI client)
  └── Same AF_UNIX protocol as the GUI
```

---

## Privacy

No analytics, no telemetry, no accounts, no external network calls. The app communicates only with its local daemon over a Unix socket at `/tmp/ventd.sock`.

---

## Contributing

Issues, compatibility reports, and PRs welcome.

When reporting on a new Mac model, use the [compatibility report template](.github/ISSUE_TEMPLATE/compatibility_report.yml) and include output of:

```bash
ventctl list
ventctl temps
ventctl daemon status
```

---

## License

MIT — see [`LICENSE`](LICENSE).
