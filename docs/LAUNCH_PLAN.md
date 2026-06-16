# Vent Launch Plan

This document is a practical product and marketing plan for launching Vent as a free, open-source macOS utility for an international audience.

## Product Positioning

### One-Liner

Vent is a free menu-bar app for controlling MacBook fans with manual RPM, automatic temperature targeting, and a safe return to macOS automatic cooling.

### Short Pitch

MacBooks often prioritize silence over temperature. Vent gives users a simple way to cool their machine earlier, keep temperatures more stable during heavy workloads, and switch back to native macOS fan control at any time.

### Target Users

- MacBook Pro users with heavy sustained workloads.
- Developers compiling large projects.
- Video editors, 3D artists, and music producers.
- Users with external monitors or clamshell setups.
- Gamers and users running Windows/Linux VMs.
- Power users who want transparent, free, open-source tooling.

### Main Promise

Free, simple, local-only fan control for MacBooks.

### Non-Negotiables

- Fully free.
- No telemetry.
- No account.
- No ads.
- No paid tier.
- Easy uninstall path.
- Safe default: `Auto` mode is always visible.

## Product Principles

1. Make the safe path obvious.
2. Hide hardware complexity from normal users.
3. Keep expert diagnostics available for advanced users.
4. Never pretend every Mac behaves the same.
5. Prefer clear status messages over silent failure.
6. Make installation and updates boring.

## What Still Needs To Be Done

### Highest Priority

- Apple Developer ID signing and notarization.
- A clear first-run onboarding screen explaining helper installation.
- Better error messages when helper installation fails.
- Screenshots and a short demo GIF in the README.

### Product Polish

- Show current mode directly in the menu-bar popover footer.
- Show current RPM and target RPM more clearly.
- Add simple presets: `Quiet`, `Balanced`, `Cool`, `Max`.
- Add `Launch at Login` toggle.
- Add automatic update check with a clear opt-in.
- Show helper update availability when bundled and installed versions differ.
- Add a one-click `Reset to Auto and Quit` action.

### Compatibility And Safety

- Collect compatibility reports by model identifier.
- Add a GUI diagnostics export button.
- Add more daemon protocol tests.
- Add tests for mode transitions.
- Add clear warnings for unsupported or partially supported Macs.
- Keep all hardcoded values centralized and documented.

### Trust And Distribution

- Keep the MIT license visible in README and releases.
- Add `SECURITY.md` for responsible vulnerability reports.
- Add `CONTRIBUTING.md`.
- Add signed release checksums.
- Add notarized DMG once a Developer ID certificate is available.

## Launch Checklist

### Before Posting Publicly

- Release a notarized build if possible.
- Add screenshots to README.
- Add a 15-30 second GIF showing install, menu-bar popover, and mode switching.
- Verify install/update on a clean macOS user account.
- Verify uninstall instructions.
- Verify `Auto` mode after app quit/reboot.
- Create GitHub issue templates.
- Pin a GitHub discussion or issue for compatibility reports.

### Release Assets

- DMG.
- SHA256 checksum.
- Short changelog.
- Screenshots.
- Demo GIF.
- Troubleshooting note for Gatekeeper if not notarized.

## Reddit Launch Draft

### Possible Titles

- `I built a free open-source menu bar fan control app for MacBooks`
- `Free open-source MacBook fan control app with Auto Temp mode`
- `I made a local-only fan control utility for Apple Silicon and Intel MacBooks`

### Post Body

Hi r/macapps,

I built **Vent**, a free and open-source macOS menu-bar app for controlling MacBook fans.

The goal is simple: make it easier to keep a MacBook cooler during sustained workloads without installing a heavy app, creating an account, or paying for a subscription.

What it does:

- `Auto`: immediately returns fan control to macOS/SMC.
- `Manual RPM`: set fan speed manually, either all fans together or separately.
- `Auto Temp`: choose a target laptop temperature and let the helper daemon adjust RPM automatically.
- Detects the actual number of fans instead of assuming a fixed fan count.
- Uses real SMC min/max RPM ranges from the machine.
- Shows average temperature from available SMC sensors.
- Runs locally. No telemetry, no accounts, no cloud.

Why I made it:

My MacBook often preferred staying quiet while getting hotter than I wanted during heavy work. I wanted something lightweight, transparent, and free that sits in the menu bar and gives me control when I need it.

It uses a privileged launchd helper because modern macOS requires elevated permissions for fan writes. The GUI has an `Install / Update` button that triggers the normal macOS admin prompt.

Important note: the app is currently ad-hoc signed. Until I set up Developer ID notarization, macOS Gatekeeper may require right-click -> Open or removing the quarantine flag after downloading.

GitHub / download:

https://github.com/Fallet666/mac-manual-rpm

I would really appreciate compatibility reports, especially:

- Mac model/year.
- Apple Silicon or Intel.
- macOS version.
- Number of fans detected.
- Whether Manual RPM and Auto Temp work correctly.

The app will stay free. Feedback on UX, safety, and installation flow is very welcome.

### First Comment

Known limitations:

- Not notarized yet, so Gatekeeper may complain.
- Fan/temperature SMC keys differ between Mac models.
- This is early software. Use `Auto` mode if anything behaves unexpectedly.
- I am collecting compatibility reports before calling it stable.

## Communities To Try

Post carefully, follow each community's self-promotion rules, and lead with transparency.

- r/macapps
- r/macbookpro
- r/macbook
- r/applehelp, only if framed as a tool and not spam
- r/opensource
- Hacker News `Show HN`
- Product Hunt, after notarization and screenshots
- GitHub Trending is organic only, but a strong README helps
- MacRumors forums
- Low End Mac forums
- Apple StackExchange only when answering relevant questions, not direct promotion

## Launch Sequence

### Phase 1: Trust And Polish

Goal: reduce install friction and improve first impression.

- Add license, screenshots, and demo GIF.
- Add notarization or at least very clear Gatekeeper instructions.
- Add uninstall button/instructions.
- Add issue templates.

### Phase 2: Soft Launch

Goal: collect compatibility data from friendly technical users.

- Post on GitHub and small communities.
- Ask for model reports, not stars.
- Fix installation and compatibility issues quickly.
- Keep a public compatibility table.

### Phase 3: Public Launch

Goal: reach broader Mac users.

- Reddit post in r/macapps.
- Show HN post.
- Short demo video.
- Product Hunt only after notarization.

### Phase 4: Retention

Goal: make users keep and recommend it.

- Auto update notification.
- Presets.
- Better helper lifecycle management.
- Clear diagnostics export.

## Messaging Guidelines

Use:

- `Free and open-source`
- `Local-only`
- `No telemetry`
- `Menu-bar app`
- `Safe Auto mode`
- `Real SMC fan ranges`

Avoid overclaiming:

- Do not say it supports every Mac.
- Do not promise lower temperatures on every model.
- Do not imply it bypasses Apple's thermal protection.
- Do not market it as a gaming performance booster.

## Success Metrics

Because the product is free and privacy-first, avoid invasive analytics. Use public, opt-in signals:

- GitHub stars.
- Release downloads.
- Issues opened and resolved.
- Compatibility reports by model.
- Reddit comments and feedback quality.
- Number of repeat contributors.

## Suggested Roadmap

### v1.1

- Screenshots and demo GIF.
- Better install/update status messages.
- Compatibility report export.
- Helper update availability when bundled and installed versions differ.

### v1.2

- Presets: `Quiet`, `Balanced`, `Cool`, `Max`.
- Launch at login toggle.
- More detailed helper diagnostics.
- Better Auto Temp tuning.

### v1.3

- Temperature/RPM history chart.
- Optional update checks.
- Public compatibility table.

### v2.0

- Developer ID notarized builds.
- Polished onboarding.
- Stable compatibility matrix.
- Localized UI.

## Free Product Sustainability

Keep the app fully free. If the project needs funding later, use optional support only:

- GitHub Sponsors.
- Buy Me a Coffee.
- Transparent donation link.
- No feature gating.
- No telemetry-based monetization.
- No paid updater.
