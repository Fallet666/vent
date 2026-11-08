<h1 align="center">🌀 Vent</h1>
<h3 align="center">Choose a temperature.<br>Let Vent handle the fans.</h3>
<p align="center">Free, open-source Mac fan control. Right in your menu bar.</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1"><img src="https://img.shields.io/badge/Download%20for%20macOS-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Download Vent"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="Free and open source"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.7"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=stable" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 or later">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="MIT license"></a>
</p>
<p align="center">
  <a href="#install">Get started</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">Screenshots</a>
</p>
<p align="center">
  <a href="README.md"><strong>English</strong></a> &nbsp; · &nbsp;
  <a href="README.ru.md">Русский</a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md">Español</a> &nbsp; · &nbsp;
  <a href="README.fr.md">Français</a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md">Português (Brasil)</a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp; · &nbsp;
  <a href="README.ja.md">日本語</a> &nbsp; · &nbsp;
  <a href="README.ko.md">한국어</a>
</p>

> [!NOTE]
> Preview build: the changes below are in [v1.3.9-beta.1](https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1). [Stable v1.3.7](https://github.com/Fallet666/vent/releases/tag/v1.3.7) remains available.
>
> Homebrew installs the stable release; use the DMG above to try this preview.

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="Target temperature, light appearance">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="Target temperature, dark appearance">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ Your temperature</strong><br><br>Pick a target. Vent adjusts the fans.</td>
    <td align="center" width="33%"><strong>👁️ Visible warnings</strong><br><br>Notice high fan speeds without sound.</td>
    <td align="center" width="33%"><strong>💚 Every mode is free</strong><br><br>No subscription. No account.</td>
  </tr>
</table>

## 🌡️ Your temperature. Your choice.

You shouldn't have to figure out which RPM to use every time your workload changes. Pick a **target temperature** in **Auto Temp**, and Vent adjusts fan speed toward it. Or choose a built-in profile and get back to what you were doing.

> [!TIP]
> Temperature control is included. **No paid tier, subscription, or account.** Vent is free software under the MIT license.

| What you want | What to choose |
|---|---|
| Let macOS manage cooling | **Auto** |
| Have Vent adjust the fans toward a temperature | **Auto Temp** |
| Set exact RPM yourself | **Manual RPM**, together or per fan |
| Switch quickly between saved setups | **Quiet**, **Normal**, **Gaming**, **Lap**, or your own profile |

A temperature target is a goal, not a guarantee: the result depends on your Mac, workload, and surroundings. Vent uses available sensor readings; the displayed temperature is not a measurement of the case or your skin.

## 👁️ See when the fans may be loud

**You don't have to hear the fans to know they're running hard.** Vent shows a visible warning in its panel when fan speeds are high. This is especially useful for deaf and hard-of-hearing users, and anyone wearing headphones.

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="Vent shows an orange text warning: Fans at 85% — may be loud">
</p>

The warning estimates possible noise from RPM: it appears when the highest current fan speed reaches 70% of the highest reported maximum speed. **It does not use a microphone or measure decibels.**

Enable **Notify when fans are loud** in Settings and allow macOS notifications. Vent checks fan speeds while the app is running, including when its panel is closed. It sends one notification per loud episode, with a small margin to avoid repeated alerts near the threshold.

## ✨ Small app, useful controls

- A compact menu-bar panel with light and dark system appearance. No Dock icon.
- Live temperature and fan speeds, with RPM controls based on reported hardware limits.
- Built-in profiles, plus save, rename, and delete your own.
- Celsius or Fahrenheit, launch at login, and configurable update checks.
- Closing the panel keeps your chosen mode running; quitting Vent returns control to macOS.
- `ventctl` for scripts and diagnostics. See the [developer guide](docs/DEVELOPMENT.md).

<a id="install"></a>

## 🚀 Get started

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### Download

1. Download the DMG from [the latest release](https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1).
2. Drag **Vent** to **Applications** and open it.
3. Follow setup to install the helper. macOS asks for an administrator password because changing fan speeds requires elevated privileges.
4. Choose **Auto Temp**, then your target temperature — or pick a profile.

The current packaging uses ad-hoc signing rather than Developer ID notarization, so macOS may block the downloaded app. Review the source and release before deciding whether to allow it in your macOS security settings.

**Requires macOS 13+ and a Mac with controllable fans.** The project includes Intel and Apple Silicon support, but sensor availability and fan control vary by model. A fanless MacBook Air has no fan to control. Please [report compatibility](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml) rather than assuming every model is supported.

## ↩️ Returning to macOS control

> [!IMPORTANT]
> **Quitting Vent returns fans to Auto.** Closing the panel keeps your selected settings running.

Vent waits for the helper to confirm automatic control before exiting. If it cannot confirm the change, it stays open and shows an error. You can also select **Auto** at any time. Settings offers **Uninstall Helper**, which returns fans to Auto and removes the helper. Delete the app separately if you no longer need it.

To receive preview updates, choose **Beta** under **Settings → Updates → Update channel**. The default is **Stable**. Switching back changes future update checks and does not downgrade the installed app.

## 🔒 Privacy

No account or analytics. Fan control happens locally through a Unix socket between the app and `ventd`.

**Automatic update checks are enabled by default** and contact GitHub for release information. Downloading an update also uses the network. Turn off **Automatically check for updates** in Settings if you don't want automatic checks.

## 💚 Help Vent reach more Macs

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Star Vent on GitHub"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Send a compatibility report"></a>
</p>

If Vent is useful to you, give the repository a star, share it with someone who needs it, or send a compatibility report. Bug reports, translations, and pull requests help too.

When reporting a hardware issue, include your Mac model, macOS version, what you expected, and the output of:

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ Build and contribute

Build instructions, CLI examples, and architecture: [developer guide](docs/DEVELOPMENT.md).

## License

[MIT](LICENSE). Use it, inspect it, and make it better.
