<h1 align="center">🌀 Vent</h1>
<h3 align="center">온도를 선택하세요.<br>팬은 Vent에 맡기세요.</h3>
<p align="center">메뉴 막대에서 바로 쓰는 무료 오픈 소스 Mac 팬 제어 도구입니다.</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/badge/macOS%EC%9A%A9%20%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Vent 다운로드"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="무료 및 오픈 소스"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=release" alt="최신 릴리스"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 이상">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="MIT 라이선스"></a>
</p>
<p align="center">
  <a href="#install">시작하기</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">스크린샷</a>
</p>
<p align="center">
  <a href="README.md">English</a> &nbsp; · &nbsp;
  <a href="README.ru.md">Русский</a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md">Español</a> &nbsp; · &nbsp;
  <a href="README.fr.md">Français</a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md">Português (Brasil)</a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp; · &nbsp;
  <a href="README.ja.md">日本語</a> &nbsp; · &nbsp;
  <a href="README.ko.md"><strong>한국어</strong></a>
</p>

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="목표 온도, 밝은 외관">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="목표 온도, 어두운 외관">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ 나만의 온도</strong><br><br>목표를 고르면 Vent가 팬을 조절합니다.</td>
    <td align="center" width="33%"><strong>👁️ 눈에 보이는 경고</strong><br><br>소리 없이도 팬이 빠르게 도는 것을 알 수 있습니다.</td>
    <td align="center" width="33%"><strong>💚 모든 모드가 무료</strong><br><br>구독도 계정도 필요 없습니다.</td>
  </tr>
</table>

## 🌡️ 내 온도, 내 선택.

작업 부하가 바뀔 때마다 어떤 RPM을 써야 할지 알아낼 필요가 없습니다. **Auto Temp**에서 **목표 온도**를 선택하면 Vent가 그 온도를 향해 팬 속도를 조절합니다. 또는 내장 프로필을 골라 하던 일로 돌아가세요.

> [!TIP]
> 온도 제어 기능이 포함되어 있습니다. **유료 등급, 구독, 계정이 없습니다.** Vent는 MIT 라이선스의 자유 소프트웨어입니다.

| 원하는 것 | 선택할 항목 |
|---|---|
| macOS가 냉각을 관리하게 하기 | **Auto** |
| Vent가 특정 온도를 향해 팬을 조절하게 하기 | **Auto Temp** |
| 정확한 RPM을 직접 설정하기 | **Manual RPM**, 함께 설정하거나 팬별로 설정 |
| 저장된 설정 간에 빠르게 전환하기 | **Quiet**, **Normal**, **Gaming**, **Lap** 또는 나만의 프로필 |

온도 목표는 보장이 아니라 목표입니다. 결과는 Mac, 작업 부하, 주변 환경에 따라 달라집니다. Vent는 사용 가능한 센서 값을 사용하며, 표시 온도는 케이스나 피부 온도의 측정값이 아닙니다.

## 👁️ 팬이 시끄러울 수 있는 때 확인하기

**팬 소리를 듣지 못해도 팬이 세게 돌고 있음을 알 수 있습니다.** 팬 속도가 높으면 Vent가 패널에 시각적 경고를 표시합니다. 이는 청각 장애인 및 난청 사용자, 그리고 헤드폰을 착용한 모든 사람에게 특히 유용합니다.

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="Vent가 주황색 텍스트 경고를 표시합니다: 팬 속도 85% — 소음이 클 수 있습니다">
</p>

이 경고는 RPM으로 가능한 소음을 추정합니다. 현재 가장 높은 팬 속도가 보고된 최고 속도의 70%에 도달하면 나타납니다. **마이크를 사용하거나 데시벨을 측정하지 않습니다.**

Settings에서 **Notify when fans are loud**를 활성화하고 macOS 알림을 허용할 수도 있습니다. 현재 구현에서는 Vent 패널이 보이는 동안에만 값이 새로 고쳐집니다. 이 옵션을 항상 켜져 있는 백그라운드 소음 알림으로 신뢰하지 마세요.

## ✨ 작은 앱, 유용한 제어

- 밝고 어두운 시스템 외관을 지원하는 간결한 메뉴 막대 패널. Dock 아이콘이 없습니다.
- 실시간 온도와 팬 속도, 그리고 보고된 하드웨어 한도에 기반한 RPM 제어.
- 내장 프로필과 함께, 나만의 프로필 저장, 이름 변경, 삭제.
- 섭씨 또는 화씨, 로그인 시 실행, 구성 가능한 업데이트 확인.
- 패널이나 앱을 닫아도 팬 제어를 계속하는 로컬 헬퍼.
- 스크립트 및 진단용 `ventctl`. [개발자 가이드](docs/DEVELOPMENT.md)를 참조하세요.

<a id="install"></a>

## 🚀 시작하기

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### 다운로드

1. [최신 릴리스](https://github.com/Fallet666/vent/releases/latest)에서 DMG를 다운로드합니다.
2. **Vent**를 **Applications**로 드래그한 뒤 엽니다.
3. 설정 절차에 따라 헬퍼를 설치합니다. 팬 속도 변경에는 상승된 권한이 필요하므로 macOS가 관리자 암호를 요청합니다.
4. **Auto Temp**를 선택한 다음 목표 온도를 고르거나, 프로필을 선택합니다.

현재 패키징은 Developer ID 공증이 아닌 임시 서명을 사용하므로, macOS가 다운로드한 앱을 차단할 수 있습니다. macOS 보안 설정에서 허용할지 결정하기 전에 소스와 릴리스를 검토하세요.

**macOS 13+ 및 제어 가능한 팬이 있는 Mac이 필요합니다.** 이 프로젝트는 Intel과 Apple Silicon을 지원하지만, 센서 가용성과 팬 제어는 모델별로 다릅니다. 팬이 없는 MacBook Air에는 제어할 팬도 없습니다. 모든 모델이 지원된다고 가정하지 말고 [호환성을 보고](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml)해 주세요.

## ↩️ macOS 제어로 돌아가기

> [!IMPORTANT]
> **패널을 닫거나 Vent를 종료해도 팬 설정은 재설정되지 않습니다.** macOS가 제어하도록 하려면 종료하기 전에 **Auto**를 선택하세요.

설치된 `ventd` 헬퍼는 앱을 닫은 뒤에도 계속 실행됩니다. Settings에는 팬을 Auto로 되돌리고 헬퍼를 제거하는 **Uninstall Helper**도 있습니다. 더 이상 필요하지 않다면 앱은 별도로 삭제하세요.

## 🔒 개인정보 보호

계정이나 분석 기능이 없습니다. 팬 제어는 앱과 `ventd` 사이의 Unix socket을 통해 로컬에서 이루어집니다.

**자동 업데이트 확인은 기본으로 활성화되어 있으며**, 릴리스 정보를 위해 GitHub에 연결합니다. 업데이트 다운로드도 네트워크를 사용합니다. 자동 확인을 원하지 않으면 Settings에서 **Automatically check for updates**를 끄세요.

## 💚 Vent를 더 많은 Mac에 알리기

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="GitHub에서 Vent에 별표 주기"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="호환성 보고서 보내기"></a>
</p>

Vent가 유용했다면 저장소에 별표를 주고, 필요한 사람과 공유하거나 호환성 보고서를 보내 주세요. 버그 보고, 번역, 풀 리퀘스트도 도움이 됩니다.

하드웨어 문제를 보고할 때는 Mac 모델, macOS 버전, 예상한 결과와 다음 명령의 출력을 포함하세요.

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ 빌드 및 기여

빌드 지침, CLI 예제, 아키텍처: [개발자 가이드](docs/DEVELOPMENT.md).

## 라이선스

[MIT](LICENSE). 사용하고, 살펴보고, 더 좋게 만들어 주세요.
