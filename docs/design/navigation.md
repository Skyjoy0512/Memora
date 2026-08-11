# ナビゲーション

## 構成

```
RootLayout
  SafeAreaView + StatusBar
    HeroUINativeProvider
      Stack
        (tabs) ← expo-router/unstable-native-tabs の NativeTabs
        file/[id] ← Stack push
        record ← fullScreenModal
        search ← modal
```

## NativeTabs

`expo-router/unstable-native-tabs` の `NativeTabs` を使用し、カスタム `tabBar` は実装しない。`minimizeBehavior="onScrollDown"` を指定する。

| 順序 | 要素 | 実装 | 役割 |
|---|---|---|---|
| 1 | ホーム | `NativeTabs.Trigger` / `.Icon` | ファイル・プロジェクト一覧 |
| 2 | タスク | `NativeTabs.Trigger` / `.Icon` | 横断タスク |
| 3 | 中央 FAB | タブではないアクション | 作成メニュー |
| 4 | AI | `NativeTabs.Trigger` / `.Icon` | AI 機能 |
| 5 | 設定 | `NativeTabs.Trigger` / `.Icon` | 設定 |

中央 FAB はタブとして登録しない。HeroUI Native `Menu.Trigger asChild` の `Button isIconOnly` であり、押下すると `Menu.Portal` 内の `Menu.Overlay` と `Menu.Content` を表示する。コンテンツは `presentation="popover"`、`placement="top"`、`align="center"` で FAB 上部に標準の scale + fade で展開し、`Menu.Item` として「録音開始」「インポート」「オンライン会議」を並べる。Overlay は `expo-blur` の `BlurView` で背景をぼかして減光する。メニュー背景は iOS 26 以上で `GlassView`、旧 iOS・Android で `BlurView` とする。

## ホームの固定要素

- `NativeTabs.BottomAccessory` に AI コンポーザーを固定し、一覧スクロール領域と分離する。
- 外枠は iOS 26 以上で `expo-glass-effect` の `GlassContainer` / `GlassView`、旧 iOS・Android は `expo-blur` の `BlurView` を使う。
- `TextArea`、添付 `Button isIconOnly`、Auto / モデル `Select`、音声入力または送信 `Button isIconOnly` を含める。
- プロジェクト表示時だけ、コンポーザー上部のピル形 GlassView 内 Select を追加し、選択肢は Bottom Sheet に表示する。

## 画面遷移

| 起点 | 操作 | 遷移先 | 方式 |
|---|---|---|---|
| ホーム | ファイルカード | ファイル詳細 | Stack push |
| 任意 | FAB → 録音開始 | 録音セットアップ | fullScreenModal |
| 任意 | FAB → インポート | インポートフロー | modal |
| 任意 | FAB → オンライン会議 | オンライン会議フロー | modal |

固定領域を含めたスクロール余白は、`NativeTabs`、`BottomAccessory`、safe area の実測値から合算する。固定値に依存しない。
