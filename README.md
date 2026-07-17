# My Tool Box

自作ツールを詰め込む iPhone 向け Flutter アプリ。サイドパネル(Drawer)からツールを切り替える構成で、今後ツールを追加していく。

## ツール

| ツール | 説明 |
|---|---|
| GitHub Projects | GitHub Projects (v2) のボードをカンバン表示。カードの長押しドラッグ or タップメニューでステータス変更、タスク追加、GitHub で開く。プロジェクトビューの設定ソート順を再現([github-project-menu-bar](../github-project-menu-bar) の移植)。 |

## セットアップ

Flutter は [mise](https://mise.jdx.dev/) で管理している(`mise.toml`)。

```bash
mise install          # Flutter SDK をインストール
mise exec -- flutter pub get
```

iOS ビルドには Xcode が必要。`xcode-select` は **full Xcode を指している必要がある**(CommandLineTools のままだと、プラグインのビルドフックが iOS SDK を見つけられずビルドが失敗する。`DEVELOPER_DIR` 環境変数だけではフックに伝播しないため不十分):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

ネイティブ依存は Swift Package Manager で解決する(CocoaPods 不要、`flutter config --enable-swift-package-manager` 有効化済み)。

## 実行

```bash
mise exec -- flutter run                    # 接続中のデバイス / シミュレータ
mise exec -- flutter build ios --simulator  # シミュレータ向けビルド
mise exec -- flutter build ios              # 実機向け(要署名設定)
```

実機に入れる場合は `ios/Runner.xcodeproj` を Xcode で開き、Signing & Capabilities で自分の Team を選択して Run する。

## GitHub Projects ツールの設定

1. アプリのボード画面右上 ⚙ → GitHub の **classic PAT** を貼り付けて「検証して保存」
   - 必要スコープ: `project`(プライベートリポジトリのカードを扱うなら `repo` も)
   - トークンは iOS Keychain に保存される
2. プロジェクトを選択するとボードが読み込まれる

## 構成

```
mise.toml                     Flutter のバージョン管理
lib/
  main.dart                   アプリ本体 + ツールレジストリ + サイドパネル
  src/
    shell/shell_scope.dart    ツール画面からサイドパネルを開くための InheritedWidget
    tools/
      tool.dart               ツール定義(id / name / icon / builder)
      github_project/
        models.dart           Project / Board / BoardCard + ビューソート再現ロジック
        github_api.dart       GitHub GraphQL API クライアント
        board_view_model.dart 状態管理(楽観的更新つき)
        board_screen.dart     カンバンボード UI
        settings_screen.dart  PAT 入力・プロジェクト選択
        status_color.dart     GitHub カラー enum → Color
        token_store.dart      Keychain / UserDefaults ラッパー
test/
  sort_test.dart              ソート再現ロジックの単体テスト
  widget_test.dart            シェルのスモークテスト
```

## ツールの追加方法

1. `lib/src/tools/<tool_name>/` に画面を実装
2. `lib/main.dart` の `tools` リストに `Tool(...)` を追加

サイドパネルには自動で表示される。

## テスト

```bash
mise exec -- flutter analyze
mise exec -- flutter test
```
