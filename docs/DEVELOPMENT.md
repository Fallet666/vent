# Developing Vent

## Build

Requirements: macOS, Xcode Command Line Tools, CMake, and SwiftPM. The GUI package targets macOS 13+. Current sources include macOS 26 glass APIs behind availability checks; building them requires an SDK that provides those APIs.

Run from the repository root:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure

(cd gui/VentGUI && swift build -c release)
(cd gui/VentGUI && swift run -c release VentGUITests)

./package_dmg.sh
```

Packaging builds universal arm64/x86_64 binaries and creates a local ad-hoc-signed app and DMG in `dist/`. It does not notarize or publish a release, or install a helper.

## CLI

Installed alongside the privileged helper:

```sh
ventctl list              # fan readings and RPM limits
ventctl temps             # available temperature sensors
ventctl daemon status     # current control mode and target
ventctl persist-all 2500  # set persistent fan RPM
ventctl unpersist-all     # return fans to automatic control
ventctl read F0Ac         # inspect a raw SMC key
```

Hardware support depends on the model and available SMC keys. Do not assume these commands work on every Mac.

## Architecture

```text
Vent.app — SwiftUI panel in the menu bar
  └─ DaemonClient — local Unix socket /tmp/ventd.sock
       └─ ventd — C++17 launchd helper with elevated privileges
            ├─ SMC fan reads and writes
            ├─ Temperature sensors (SMC / Apple Silicon HID)
            ├─ Temperature-based fan control
            └─ Fan override reconciliation

ventctl — CLI using the same local protocol
```

Closing the panel preserves the selected mode. Quitting the app waits for the helper to acknowledge Auto; an error keeps the app open. The launchd helper itself remains installed. Update checks and downloads use GitHub separately from the local fan-control protocol.

## Documentation images

On macOS 14.4+ with a current SDK:

```sh
./scripts/capture-screenshots.sh
```

Set `SDKROOT` to select a particular installed macOS SDK if your default toolchain cannot build the SwiftUI sources.

The script compiles the actual GUI view sources with a separate capture entry point, briefly shows sample windows, and saves light/dark PNGs in `docs/images/`. ScreenCaptureKit captures only this process’s own windows so the glass and material layers remain visible; it does not request access to other apps or the desktop. Values are deterministic sample readings, not measurements or cooling benchmarks. It never launches the app delegate or helper. The capture manager blocks refresh, uses an isolated nonexistent socket path, and runs with loud-fan notifications disabled. No fan-control commands are sent.

The images show system light/dark appearance, not additional custom themes. They are rendered with the local macOS SDK and can differ from older systems. Re-run after visible UI changes.

## Lifecycle regression checks

Run from the repository root in a logged-in macOS GUI session:

```sh
python3 gui/VentGUI/Tests/VentGUIIntegration/run.py
```

The harness compiles the actual GUI sources and runs them against a private fake Unix-socket helper. It tests hidden-panel alerts, disabled monitoring, failed notification retries, connection loss, queued writes and termination acknowledgement/errors/timeouts. It does not change real fan settings or establish delivery of banners by macOS.
