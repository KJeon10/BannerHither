<p align="center">
  <img src="../assets/readme-banner.png" alt="BannerHither — 見ている画面に通知を" width="720">
</p>

# BannerHither

[English](../README.md) | [한국어](README.ko.md) | 日本語 | [简体中文](README.zh-Hans.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Español](README.es.md)

[![CI](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml/badge.svg)](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)

BannerHitherは、macOSの通知バナーを**どのディスプレイに表示するか**を決める小さなメニューバーアプリです。macOSはバナーを常に主ディスプレイに表示しますが、モニタが複数あると、それが今見ている画面ではないことがよくあります。BannerHitherはバナーが現れた瞬間に、マウスポインタのある画面、作業中のウインドウがある画面、または指定した1台のディスプレイへバナーを移動します。

<!-- Demo video: paste the GitHub-hosted mp4 URL here on its own line -->

## インストール

### ダウンロード

1. [Releases](https://github.com/KJeon10/BannerHither/releases)ページから`BannerHither-<バージョン>.dmg`を入手します。
2. イメージを開き、`BannerHither.app`をApplicationsのショートカットにドラッグします。
3. アプリケーションフォルダから起動します。アプリとイメージはどちらもDeveloper IDで署名・公証済みなので、macOSは警告なしに開きます。

### Homebrew

```sh
brew install --cask KJeon10/tap/bannerhither
```

### 自分でビルド

自分でビルドする場合は[ソースからビルド](#ソースからビルド)を参照してください。

### 初回起動

BannerHitherは**アクセシビリティ**の権限（システム設定 › プライバシーとセキュリティ › アクセシビリティ）を求めます。この権限があることで、NotificationCenterのウインドウを動かせるようになります。許可するとエンジンが自動的に開始し、実行中はメニューバーのアイコンがバッジ付きのベルになります。

メニューの*テスト通知を送信*を使ってみてください。3秒後に通知が届くので、その間にマウスを別のディスプレイへ移動して、バナーがどこに表示されるかを確認できます。

## 機能

- **マウスポインタのある画面** — 使っているディスプレイにバナーが付いてきます。
- **アクティブなウインドウのある画面** — フォーカスのあるウインドウの隣にバナーが表示されます。判定できない場合はマウスのある画面に切り替わります。
- **特定のディスプレイ** — 常に指定したモニタに表示します。そのモニタが外されている間は、再接続されるまでmacOSの標準動作のままです。
- **システムのデフォルト** — 何もせず、メニューバーに常駐するだけです。
- Dockアイコンのないメニューバー専用アプリ。開始/停止の切り替え、ログイン時に開く、マウスを動かす時間を確保する3秒遅延のテスト通知、バグ報告用の*診断情報をコピー*。
- ユニバーサルバイナリ（AppleシリコンとIntel）。UIは英語、韓国語、日本語、簡体中国語、ドイツ語、フランス語、スペイン語に対応。
- 必要な権限はアクセシビリティのみ。ネットワークアクセスもデータ収集もありません。

## 仕組み

`NotificationCenter.app`はすべてのバナーを、ディスプレイと同じ大きさの透明なウインドウ1枚の中に描画し、バナーを表示するたびにそのウインドウを主ディスプレイに配置します。BannerHitherは公開されているAccessibility APIを通じてNotificationCenterを監視し、バナーウインドウがデフォルトの位置に現れたら、ウインドウの`AXPosition`を設定して右上の角を選んだディスプレイの右上の角に合わせます。これで、macOSがそのディスプレイにネイティブに描画した場合とまったく同じ位置にバナーが来ます。ウインドウ全体が移動するので、クリック、スワイプ、閉じるボタンはそのまま機能します。

アプリが介入するのは*状態が変わった時*（バナーが現れた直後、またはNotificationCenterが再配置した直後）だけなので、表示済みのバナーがマウスを追いかけることはありません。時計をクリックしたディスプレイにNotificationCenterが配置する通知センターのパネルにも一切触れません。

この方法はNotificationCenterの非公開の挙動に依存しており、AppleがmacOSのアップデートで変える可能性があります。ウインドウを見つけられない、または動かせなくなった場合、BannerHitherは失敗をログに記録し、macOSは通常どおり動作します。それ以外への影響はありません。*診断情報をコピー*は現在のNotificationCenterウインドウの属性をダンプするので、バグ報告からそうした変化を診断できます。

### 検証済みのmacOSバージョン

| macOS | 状態 |
| --- | --- |
| 26.6 (Tahoe) | 検証済み：バナーウインドウの検出、移動、NotificationCenter再起動後の復帰を確認 |
| 14.0 – 15.x | ビルド可能で動作するはずですが（ウインドウ構造はBig Sur以降変わっていない）、未検証 |

### 既知の制限

- 移動先のディスプレイが、バナーウインドウの元のサイズより狭い場合、ウインドウがディスプレイの左端からはみ出します。バナー自体は完全に表示されます。気になる場合は、後述の`resizeToTargetScreen`オプションでウインドウを先にリサイズできます。
- 他のディスプレイをミラーリングしているディスプレイは、別の移動先にはなりません。
- *ディスプレイごとに個別の操作スペース*をオフにした状態、ステージマネージャ、ロック画面では未検証です。

## 詳細設定

メニューの項目はすべて`io.github.kjeon10.BannerHither`の`UserDefaults`に保存されます。メニューにないオプションが2つあります。

| キー | デフォルト | 意味 |
| --- | --- | --- |
| `pollIntervalMilliseconds` | `1000` | 保険としてのポーリング間隔。アプリはAccessibilityのイベントで動作し、ポーリングは取りこぼしたイベントとNotificationCenterの再起動を補うだけです。`0`でポーリングを無効化（50–5000を受け付けます）。 |
| `resizeToTargetScreen` | `false` | 移動する前に、バナーウインドウを移動先ディスプレイの大きさにリサイズします。 |

```sh
defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500
defaults write io.github.kjeon10.BannerHither resizeToTargetScreen -bool true
```

変更は次のバナーから有効になります。アプリの動作を追うには：

```sh
log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
```

## ソースからビルド

必要環境：macOS 14以降、Xcode 16以降（または対応するCommand Line Tools）。

```sh
git clone https://github.com/KJeon10/BannerHither.git
cd BannerHither
make build          # → build/BannerHither.app
open build/BannerHither.app
```

アプリが求めるアクセシビリティの権限を許可すれば完了です。

## プライバシー

BannerHitherは通知の内容を読まず、外部と通信しません。必要なら[ソースから自分でビルド](#ソースからビルド)することもできます。

## クレジット

[PingPlace](https://github.com/NotWadeGrimridge/PingPlace)、[ShoveIt](https://github.com/JaysonRawlins/ShoveIt)、[NotificationNanny](https://github.com/chessper53/NotificationNanny)を参考にしました。

## ライセンス

[MIT](../LICENSE) © 2026 [KJeon10](https://github.com/KJeon10)
