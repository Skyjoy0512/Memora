# ADR-001: NativeTabs と中央 FAB メニュー

- 状態: 採用
- 日付: 2026-07-26

## 決定

Expo Router の `expo-router/unstable-native-tabs` による `NativeTabs` を採用する。カスタム `tabBar` は作らない。`NativeTabs` は `minimizeBehavior="onScrollDown"` とし、`NativeTabs.Trigger` / `NativeTabs.Trigger.Icon` でホーム、タスク、AI、設定を登録する。

中央のボタンは引き続き**タブとして登録しない**。ただし、録音へ直接遷移するボタンではなく、HeroUI Native `Menu.Trigger asChild` 内の `Button isIconOnly` による FAB とする。FAB は次の `Menu.Item` を持つ popover メニューを開く。

1. 録音開始
2. インポート
3. オンライン会議

メニューは `Menu.Portal` の `Menu.Overlay` と `Menu.Content` を用い、`presentation="popover"`、`placement="top"`、`align="center"` で FAB 上部へ表示する。標準の scale + fade を使う。Overlay は `scrim` で減光し、メニュー背景は iOS 26 以上では `@callstack/liquid-glass`（導入済み）、iOS 26 未満・Android・Reduce Transparency 時は `theme/tokens.ts` の `glassFallback` / `glassBorderFallback` を使った不透明 Surface/View でフォールバックする。

## 理由

中央アクションをタブにしないことで、選択状態と録音状態を混同しない。一方で FAB をメニュー化することで、録音だけでなくインポートとオンライン会議を同じ作成起点から発見可能にする。

`NativeTabs` を使うことでネイティブのタブ挙動とスクロール時の最小化を得る。AI コンポーザーは `NativeTabs.BottomAccessory` に置き、タブバーの一段上に常駐させる。

## 帰結

- 録音開始は FAB から 1 タップ、他の作成手段も同じ 1 タップで選択できる。
- FAB は tab route ではないため、録音・インポート・会議開始後の画面遷移はそれぞれ modal / fullScreenModal として管理する。
- `V6FloatingTabBar` と独自 `TabBar` の実装方針を取り下げる。
- iOS 26 未満・Android・Reduce Transparency 時は `@callstack/liquid-glass` を使わず、意味論トークン `glassFallback` / `glassBorderFallback` の不透明 Surface/View でフォールバックする。`expo-glass-effect` / `expo-symbols` / `expo-blur` は必須としない（追加しない）。
