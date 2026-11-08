<h1 align="center">🌀 Vent</h1>
<h3 align="center">温度を選ぶ。<br>ファンは Vent に任せる。</h3>
<p align="center">無料・オープンソースの Mac 用ファン制御。メニューバーからすぐ使えます。</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.8-rc.1"><img src="https://img.shields.io/badge/macOS%20%E7%89%88%E3%82%92%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Vent をダウンロード"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="無料かつオープンソース"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.7"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=stable" alt="最新リリース"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 以降">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="MIT ライセンス"></a>
</p>
<p align="center">
  <a href="#install">はじめる</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">スクリーンショット</a>
</p>
<p align="center">
  <a href="README.md">English</a> &nbsp; · &nbsp;
  <a href="README.ru.md">Русский</a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md">Español</a> &nbsp; · &nbsp;
  <a href="README.fr.md">Français</a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md">Português (Brasil)</a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp; · &nbsp;
  <a href="README.ja.md"><strong>日本語</strong></a> &nbsp; · &nbsp;
  <a href="README.ko.md">한국어</a>
</p>

> [!NOTE]
> プレビュービルド：以下の変更は [v1.3.8-rc.1](https://github.com/Fallet666/vent/releases/tag/v1.3.8-rc.1) に含まれています。安定版 [v1.3.7](https://github.com/Fallet666/vent/releases/tag/v1.3.7) も引き続き利用できます。
>
> Homebrew では安定版がインストールされます。このプレビューを試すには、上のリンクから DMG をダウンロードしてください。

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="目標温度、ライト外観">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="目標温度、ダーク外観">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ 自分の温度</strong><br><br>目標を選べば、Vent がファンを調整します。</td>
    <td align="center" width="33%"><strong>👁️ 見える警告</strong><br><br>音がなくてもファンの高速動作に気づけます。</td>
    <td align="center" width="33%"><strong>💚 すべてのモードが無料</strong><br><br>サブスクリプションもアカウントも不要です。</td>
  </tr>
</table>

## 🌡️ 自分の温度、自分の選択。

作業負荷が変わるたびに、どの RPM を使うか考える必要はありません。**Auto Temp** で**目標温度**を選ぶと、Vent はそれに向けてファン速度を調整します。内蔵プロファイルを選んで、作業に戻ることもできます。

> [!TIP]
> 温度制御は含まれています。**有料プラン、サブスクリプション、アカウントはありません。**Vent は MIT ライセンスのフリーソフトウェアです。

| やりたいこと | 選ぶもの |
|---|---|
| macOS に冷却を管理させる | **Auto** |
| Vent に温度へ向けてファンを調整させる | **Auto Temp** |
| 正確な RPM を自分で設定する | **Manual RPM**、全ファン一括またはファンごと |
| 保存済み設定をすばやく切り替える | **Quiet**、**Normal**、**Gaming**、**Lap**、または独自のプロファイル |

温度目標は保証ではなく目標です。結果は Mac、作業負荷、周囲の環境に依存します。Vent は利用可能なセンサー値を使います。表示温度は筐体や皮膚の温度の測定値ではありません。

## 👁️ ファンがうるさいかもしれないときに気づく

**ファンの音が聞こえなくても、高速で回っていることは分かります。**ファン速度が高いとき、Vent はパネルに視覚的な警告を表示します。これは、ろう者・難聴者の方や、ヘッドホンを着けている方にとくに役立ちます。

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="Vent がオレンジ色のテキスト警告「ファンは最大回転数の85%で動作中 — 音が大きい可能性があります」を表示している">
</p>

警告は RPM から騒音の可能性を推定します。現在の最も高いファン速度が、報告された最高速度の 70% に達すると表示されます。**マイクは使用せず、デシベルも測定しません。**

Settings で **Notify when fans are loud** を有効にし、macOS 通知を許可することもできます。Vent アプリが実行中なら、パネルを閉じていても値は更新されます。

## ✨ 小さなアプリ、便利な操作

- ライト／ダークのシステム外観に対応したコンパクトなメニューバーパネル。Dock アイコンはありません。
- リアルタイムの温度とファン速度、および報告されたハードウェア上限に基づく RPM 制御。
- 内蔵プロファイルに加え、独自プロファイルの保存、名前変更、削除。
- 摂氏／華氏、ログイン時起動、設定可能な更新チェック。
- パネルを閉じても選択したモードを維持するローカルヘルパー。アプリを終了すると、ファンは macOS の Auto 制御に戻ります。
- スクリプトと診断用の `ventctl`。 [開発者ガイド](docs/DEVELOPMENT.md)を参照してください。

<a id="install"></a>

## 🚀 はじめる

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### ダウンロード

1. [最新リリース](https://github.com/Fallet666/vent/releases/tag/v1.3.8-rc.1)から DMG をダウンロードします。
2. **Vent** を **Applications** にドラッグして開きます。
3. セットアップに従ってヘルパーをインストールします。ファン速度の変更には昇格された権限が必要なため、macOS は管理者パスワードを求めます。
4. **Auto Temp** を選び、目標温度を選択します。あるいはプロファイルを選びます。

現在のパッケージは Developer ID による公証ではなくアドホック署名を使用しているため、macOS がダウンロードしたアプリをブロックする場合があります。macOS のセキュリティ設定で許可するか決める前に、ソースとリリースを確認してください。

**macOS 13+ と、制御可能なファンを搭載した Mac が必要です。**このプロジェクトは Intel と Apple Silicon をサポートしていますが、センサーの利用可否とファン制御はモデルによって異なります。ファンレスの MacBook Air には制御するファンがありません。すべてのモデルがサポートされていると考えず、[互換性を報告](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml)してください。

## ↩️ macOS の制御に戻す

> [!IMPORTANT]
> **パネルを閉じても選択したファンモードは維持されます。Vent を終了すると、ファンは macOS の Auto 制御に戻ります。**

アプリは終了前に `ventd` ヘルパーから Auto の確認応答を待ちます。確認できない場合、Vent は開いたままとなりエラーを表示します。Settings には **Uninstall Helper** もあり、ファンを Auto に戻してヘルパーを削除します。アプリが不要になった場合は、別途削除してください。

## 🔒 プライバシー

アカウントも分析機能もありません。ファン制御は、アプリと `ventd` 間の Unix socket を通じてローカルで行われます。

**自動更新チェックはデフォルトで有効**であり、リリース情報を取得するために GitHub へ接続します。更新のダウンロードにもネットワークを使用します。自動チェックを望まない場合は、Settings で **Automatically check for updates** をオフにしてください。

## 💚 Vent をより多くの Mac に届ける

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="GitHub で Vent にスターを付ける"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="互換性レポートを送る"></a>
</p>

Vent が役に立ったら、リポジトリにスターを付け、必要としている人に共有するか、互換性レポートを送ってください。バグ報告、翻訳、プルリクエストも役立ちます。

ハードウェアの問題を報告する際は、Mac のモデル、macOS バージョン、期待した結果、および次の出力を含めてください。

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ ビルドと貢献

ビルド手順、CLI の例、アーキテクチャ：[開発者ガイド](docs/DEVELOPMENT.md)。

## ライセンス

[MIT](LICENSE)。使い、調べ、より良くしてください。
