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

Build the current DMG with `./package_dmg.sh` first, then run from the repository root in a logged-in macOS GUI session:

```sh
python3 gui/VentGUI/Tests/VentGUIIntegration/run.py
```

The harness compiles the actual GUI sources and runs them against a private fake Unix-socket helper. It tests hidden-panel alerts, disabled monitoring, failed notification retries, connection loss, queued writes and termination acknowledgement/errors/timeouts. It does not change real fan settings or establish delivery of banners by macOS.

It also tests update-channel changes and stale asynchronous responses using an injected release fetcher, and exercises the real URLSession/JSON decoder with URLProtocol fixtures (pagination, HTTP failures and malformed responses).

## Update channels

Settings → Updates offers Stable (default) and Beta. The selection persists across app updates. Stable uses GitHub's designated `/releases/latest`; Beta scans published release pages and selects the highest valid semantic version with a Vent DMG, including stable releases. Drafts and malformed tags are excluded. Switching channels invalidates previous checks and clears their cached offer. It checks immediately only if automatic checks are enabled; manual checks work in either channel. Switching to Stable does not downgrade an installed beta.

Beta and stable use the same bundle identifier and installation path. A stable version is newer than its beta/RC, so it replaces the beta through the same updater and preserves preferences, including the selected channel. The updater downloads into a private directory, validates and stages the new bundle before asking the helper for Auto, waits for the old process to exit and renames the staged bundle into place. A failed rename or rejected LaunchServices open restores the previous bundle. A later crash after LaunchServices accepts the launch is outside that rollback check.

The integration harness also mounts the real DMG to test preparation and runs the actual replacement script against a tiny isolated application. It checks beta replacement, actual LaunchServices restart, retained preferences, rollback and helper-update version gating. It never installs over the user's Vent app.

## Release workflow: beta → stable

1. Set `APP_VERSION` in `include/daemon_ipc.h` and the numeric core in `CMakeLists.txt`, commit the reviewed product changes and push the branch. Beta versions use a suffix, such as `1.4.0-beta.1`.
2. Build and test locally, then publish the beta with `./release.sh 1.4.0-beta.1 --notes-file /path/to/notes.md`. The version suffix automatically marks a prerelease; it never changes Homebrew or latest stable.
3. After verification, change the version to `1.4.0`, update the documentation and merge the reviewed changes into `main`. Build and run the GUI, daemon and native integration checks.
4. Publish from the pushed `main` with `./release.sh 1.4.0 --notes-file /path/to/notes.md`. It checks the published DMG checksum and GitHub latest, updates and verifies Homebrew, then removes obsolete published beta/alpha/RC release entries whose version core is no newer than the stable version. Drafts, future betas, stable releases and all Git tags are preserved.

`release.sh` never edits sources, commits files or pushes the product branch. Product and release inputs must already be committed; unrelated launch drafts are excluded. `--artifact dist/Vent-1.4.0.dmg` can reuse a verified build only with the matching `.build.json` generated by `package_dmg.sh`: exact commit, version, SHA-256 and clean product inputs must match. Otherwise the script builds and runs the model tests. The manifest records local build provenance, not a publisher signature.

Existing tags are immutable. If a publication step fails, inspect the release/tag, downloaded asset and Homebrew state before continuing the remaining steps; do not rebuild or overwrite an already published artifact. Obsolete previews are removed only after stable release and Homebrew verification succeed. The new stable release is available in both update channels; retaining Beta means opting into future previews, not retaining a second installed app.

See the [GitHub releases API](https://docs.github.com/en/rest/releases/releases) and [SemVer precedence rules](https://semver.org/#spec-item-11).
