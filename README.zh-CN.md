<h1 align="center">🌀 Vent</h1>
<h3 align="center">选择一个温度。<br>让 Vent 管理风扇。</h3>
<p align="center">免费、开源的 Mac 风扇控制工具，就在菜单栏中。</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1"><img src="https://img.shields.io/badge/%E4%B8%8B%E8%BD%BD%20macOS%20%E7%89%88-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="下载 Vent"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="免费且开源"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.7"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=stable" alt="最新版本"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 或更高版本">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="MIT 许可证"></a>
</p>
<p align="center">
  <a href="#install">开始使用</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">截图</a>
</p>
<p align="center">
  <a href="README.md">English</a> &nbsp; · &nbsp;
  <a href="README.ru.md">Русский</a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md">Español</a> &nbsp; · &nbsp;
  <a href="README.fr.md">Français</a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md">Português (Brasil)</a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md"><strong>简体中文</strong></a> &nbsp; · &nbsp;
  <a href="README.ja.md">日本語</a> &nbsp; · &nbsp;
  <a href="README.ko.md">한국어</a>
</p>

> [!NOTE]
> 预览构建：下文所述更改包含在 [v1.3.9-beta.1](https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1) 中。稳定版 [v1.3.7](https://github.com/Fallet666/vent/releases/tag/v1.3.7) 仍可使用。
>
> Homebrew 安装的是稳定版；如需试用此预览版，请通过上方链接下载 DMG。

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="目标温度，浅色外观">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="目标温度，深色外观">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ 你的温度</strong><br><br>设定目标，Vent 会调节风扇。</td>
    <td align="center" width="33%"><strong>👁️ 可见警告</strong><br><br>无需声音，也能注意到风扇高速运转。</td>
    <td align="center" width="33%"><strong>💚 所有模式均免费</strong><br><br>无需订阅，无需账户。</td>
  </tr>
</table>

## 🌡️ 你的温度，你来选择。

每次工作负载变化时，你不该都得判断该用多少 RPM。在 **Auto Temp** 中选择一个**目标温度**，Vent 会向该温度调节风扇转速。或者选择内置配置文件，继续手头的工作。

> [!TIP]
> 温度控制功能已包含在内。**没有付费版、订阅或账户。**Vent 是采用 MIT 许可证的自由软件。

| 你的需求 | 选择项 |
|---|---|
| 让 macOS 管理散热 | **Auto** |
| 让 Vent 将风扇调节到接近某个温度 | **Auto Temp** |
| 自行设定精确 RPM | **Manual RPM**，可统一设置或分别设置每个风扇 |
| 在已保存的设置间快速切换 | **Quiet**、**Normal**、**Gaming**、**Lap**，或自己的配置文件 |

温度目标是一个目标而非保证：结果取决于你的 Mac、工作负载和周围环境。Vent 使用可用的传感器读数；显示的温度并不是机身或皮肤温度的测量值。

## 👁️ 了解风扇何时可能很响

**无需听到风扇声，也能知道它们正在高速运转。**风扇转速较高时，Vent 会在面板中显示可见警告。这对失聪和听力障碍用户，以及佩戴耳机的任何人尤其有用。

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="Vent 显示橙色文字警告：风扇处于 85% — 可能很响">
</p>

该警告根据 RPM 估计可能的噪声：当前最高风扇转速达到报告的最高转速的 70% 时就会显示。**它不使用麦克风，也不测量分贝。**

你还可以在 Settings 中启用 **Notify when fans are loud**，并允许 macOS 发送通知。Vent 应用正在运行时，即使面板关闭，读数也会刷新。

## ✨ 小巧应用，实用控制

- 紧凑的菜单栏面板，支持浅色和深色系统外观。没有 Dock 图标。
- 实时温度和风扇转速，并基于报告的硬件限制提供 RPM 控制。
- 内置配置文件，也可保存、重命名和删除自己的配置文件。
- 摄氏度或华氏度、登录时启动，以及可配置的更新检查。
- 关闭面板后仍会保留所选模式的本地辅助程序；退出应用后，风扇会恢复由 macOS 的 Auto 控制。
- 用于脚本和诊断的 `ventctl`。参阅[开发者指南](docs/DEVELOPMENT.md)。

<a id="install"></a>

## 🚀 开始使用

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### 下载

1. 从[最新版本](https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1)下载 DMG。
2. 将 **Vent** 拖到 **Applications** 中并打开。
3. 按照设置流程安装辅助程序。macOS 会要求输入管理员密码，因为更改风扇转速需要提升权限。
4. 选择 **Auto Temp**，再选择目标温度；或者选择一个配置文件。

当前打包使用的是临时签名，而非 Developer ID 公证，因此 macOS 可能会阻止下载的应用。请在决定是否允许其通过 macOS 安全设置运行之前，审查源代码和发行版本。

**需要 macOS 13+ 和一台带有可控制风扇的 Mac。**项目支持 Intel 和 Apple Silicon，但传感器可用性和风扇控制因机型而异。无风扇的 MacBook Air 没有可控制的风扇。请[报告兼容性](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml)，不要假定每个机型都受支持。

## ↩️ 恢复由 macOS 控制

> [!IMPORTANT]
> **关闭面板会保留所选风扇模式；退出 Vent 会让风扇恢复由 macOS 的 Auto 控制。**

退出前，应用会等待 `ventd` 辅助程序确认 Auto；如果无法确认，Vent 会保持打开并显示错误。Settings 还提供 **Uninstall Helper**，它会让风扇恢复为 Auto 并移除辅助程序。如果不再需要应用，请另行删除它。

## 🔒 隐私

没有账户，也没有分析功能。风扇控制通过应用和 `ventd` 之间的 Unix socket 在本地完成。

**默认启用自动更新检查**，并会联系 GitHub 获取发行版本信息。下载更新也会使用网络。如果不希望自动检查，请在 Settings 中关闭 **Automatically check for updates**。

## 💚 帮助 Vent 覆盖更多 Mac

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="在 GitHub 上为 Vent 点星"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="发送兼容性报告"></a>
</p>

如果 Vent 对你有帮助，请为仓库点星、分享给需要它的人，或发送一份兼容性报告。错误报告、翻译和拉取请求同样有帮助。

报告硬件问题时，请附上你的 Mac 机型、macOS 版本、预期结果以及以下命令的输出：

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ 构建与贡献

构建说明、CLI 示例和架构：[开发者指南](docs/DEVELOPMENT.md)。

## 许可证

[MIT](LICENSE)。使用它、审阅它，让它变得更好。
