# CaretMode

テキストカーソル付近に現在の入力モードを**常時表示**する macOS ユーティリティ。

「今ひらがな？英字？」と迷うことをなくします。

## 特徴

- キャレット付近に入力モード（あ / A / ア 等）を常時表示
- カーソル移動に追従
- 入力モード切替を即座に反映（CGEvent tap によるリアルタイム検知）
- 完全イベント駆動（ポーリングなし）
- 多言語対応（日本語・中国語・韓国語 等、`kTISPropertyInputModeID` ベース）
- 入力ソースごとのラベル・色をカスタマイズ可能

## 動作環境

- macOS 14 Sonoma 以降
- Apple Silicon（M1 以降）

## インストール

### ビルド

```bash
brew install xcodegen   # 未インストールの場合
cd /path/to/caretmode
xcodegen generate
xcodebuild -project CaretMode.xcodeproj -scheme CaretMode \
  -configuration Release CONFIGURATION_BUILD_DIR="$(pwd)/dist" build
open dist/CaretMode.app
```

### 開発用スクリプト

```bash
./scripts/run.sh
```

ビルド + 権限リセット + 起動を一括で行います。

## 必要な権限

初回起動時に設定パネルが開きます。以下の権限を付与してください。

| 権限 | 用途 |
|-----|------|
| アクセシビリティ | テキストカーソル位置の取得（AX API） |
| 入力監視 | 入力モード切替のリアルタイム検知（CGEvent tap） |

**システム設定 → プライバシーとセキュリティ** から CaretMode を許可してください。

## 設定

メニューバーアイコン → 「設定…」から設定パネルを開けます。

### 一般
- メニューバーアイコンの表示/非表示
- ログイン時に自動起動
- 権限状態の確認

### 外観
- インジケータサイズ（小 / 中 / 大）
- 不透明度
- カーソルからのオフセット（X / Y）
- 角丸（border radius）
- ボーダー（色・不透明度・太さ、入力ソース色の引き継ぎ/カスタム色の選択）

### 入力ソース
- インストール済み入力ソースの一覧
- 各入力ソースのラベル（1〜2文字）と色をカスタマイズ
- 未知の入力ソースは自動でラベルを推定

### 除外アプリ
- 指定したアプリではインジケータを非表示

## アーキテクチャ

```
CaretMode/
├── App/
│   ├── CaretModeApp.swift              # @main, MenuBarExtra
│   └── AppDelegate.swift               # コンポーネント接続、設定ウィンドウ管理
├── Core/
│   ├── InputSourceMonitor.swift         # 入力ソース監視（TIS API + CGEvent tap）
│   ├── CaretPositionTracker.swift       # カーソル位置追跡（AXObserver + NSWorkspace 通知）
│   ├── IndicatorWindowController.swift  # NSPanel 管理（フローティング表示）
│   └── AccessibilityManager.swift       # AX 権限管理
├── Views/
│   ├── IndicatorView.swift              # インジケータ（SwiftUI）
│   ├── SettingsView.swift               # 設定画面（4タブ）
│   └── OnboardingView.swift             # 権限ガイド
├── Models/
│   ├── InputSourceInfo.swift            # 入力ソース情報（kTISPropertyInputModeID ベース）
│   ├── InputModeConfig.swift            # ラベル・色設定 + ビルトインデフォルト
│   ├── AppSettings.swift                # 全設定の @Observable モデル
│   └── ExcludedApp.swift                # 除外アプリモデル
├── Utilities/
│   ├── AXHelpers.swift                  # Accessibility API ラッパー
│   └── NSScreen+Extensions.swift        # AX座標 ↔ AppKit座標 変換
└── Resources/
    └── Assets.xcassets/                 # アプリアイコン
```

### イベント駆動アーキテクチャ

ポーリングは一切使わず、すべてイベント/通知で駆動します。

| イベントソース | 検知対象 |
|---|---|
| `CGEvent.tapCreate` | キー入力 → 入力ソース切替の即時検知 |
| `DistributedNotificationCenter` | 入力ソース変更通知（フォールバック） |
| `AXObserver` | フォーカス要素変更、テキスト選択変更、ウィンドウ切替 |
| `NSWorkspace.didActivateApplicationNotification` | アプリ切替 |

各コンポーネントは `onChange` コールバックで `AppDelegate.updateIndicator()` を呼び出し、インジケータの表示/非表示/位置を更新します。

## ライセンス

MIT License
