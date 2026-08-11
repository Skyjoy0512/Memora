# ホーム

ルート: `app/(tabs)/index.tsx`
種別: Expo Router `NativeTabs` のホーム

## Purpose

ファイルまたはプロジェクトを切り替え、直近の内容をフラットな一覧で再訪・操作する。挨拶、日付、処理中、最近、未完了タスクのセクション分割は行わない。

## Layout

```
┌─────────────────────────────────┐
│ Safe Area 内ヘッダー              │
│ [ファイル ▾]              [検索][絞込] │
├─────────────────────────────────┤
│ FlashList                         │
│ ┌─────────────────────────────┐ │
│ │ 要約済み                  […] │ │
│ │ Growth 定例: 7月施策レビュー │ │
│ │ 説明（最大2行）              │ │
│ │ 昨日 10:02 · 48:12           │ │
│ └─────────────────────────────┘ │
│                 …（同形式3件）   │
├─────────────────────────────────┤
│ NativeTabs.BottomAccessory       │
│ [ Ask anything...              ] │
│ [+] [Auto ▾]                 [音声][送信] │
├─────────────────────────────────┤
│ ホーム / タスク / [+] / AI / 設定 │
└─────────────────────────────────┘
```

- `react-native-safe-area-context` の `SafeAreaView` と `expo-status-bar` の `StatusBar` を使い、iOS のステータスバー領域内にヘッダーを配置する。
- ヘッダー左は HeroUI Native `Select`。`ファイル` / `プロジェクト` の選択に応じて `FlashList` のデータを切り替える。
- 右側は HeroUI Native `Button isIconOnly` と `expo-symbols` の `SymbolView` による高頻度操作を最大2個（検索・フィルター）置く。
- 一覧と AI コンポーザーは分離する。コンポーザーは `NativeTabs.BottomAccessory` に置き、スクロールに関わらず NativeTabs の一段上へ常駐させる。

## Components

| 要素 | 構成 |
|---|---|
| 表示切替 | `Select.Trigger` / `Select.Value` / `Select.TriggerIndicator` |
| 表示切替のポップオーバー | `Select.Portal` → `Select.Overlay`（`BlurView`）+ `Select.Content`。`presentation="popover"`、`placement="bottom"`、`align="start"` |
| 選択肢 | `Select.Item` / `Select.ItemLabel` / `Select.ItemIndicator`（選択中の ✓） |
| 一覧 | `@shopify/flash-list` の `FlashList` |
| ファイルカード | `Card.Body` / `Card.Title` / `Card.Description`、`Chip`、`Menu`（…） |
| AI コンポーザー | `TextArea`、`Button isIconOnly`、`Select`。placeholder は `Ask anything...` |
| プロジェクト時の選択 | コンポーザー上部の `Select`。トリガーは GlassView 内のピル、コンテンツは `BottomSheet` |

`Select.Content` と `Menu.Content` の背景は iOS 26 以上で `expo-glass-effect` の `GlassView`、旧 iOS と Android では `expo-blur` の `BlurView` を用いる。いずれも標準の scale + fade で開閉する。

## Interactions

| 操作 | 結果 |
|---|---|
| ヘッダー Select | ファイル / プロジェクトを切り替え、一覧データを更新 |
| カードをタップ | Reanimated で `scale: 1.0 → 0.98` の押下フィードバック後、Expo Router `Stack` でファイル詳細へ push |
| カードの … | `Menu` でそのファイルの補助操作を表示 |
| 添付 / Auto / 音声 / 送信 | 常駐 AI コンポーザーの入力操作 |
| 中央 FAB | `Menu` を開き、録音開始 / インポート / オンライン会議を選択 |

## States

| 状態 | 表示 |
|---|---|
| ファイル | ファイルカードのフラットな一覧 |
| プロジェクト | プロジェクトデータの一覧と、コンポーザー上部のプロジェクト Select |
| 空 | 選択中の表示種別に対応した空状態。コンポーザーと NativeTabs は常駐 |
| 読み込み | カード形状に合わせた `SkeletonGroup` |
| エラー | `Alert` と再試行。コンポーザーと NativeTabs は維持 |

## Accessibility

- ヘッダー Select は現在の選択値を含めて読み上げる（例: 「表示切替、ファイル」）。
- `Button isIconOnly` はアイコンのみで意味が伝わらないため、すべて `accessibilityLabel` を必須とする。
- ファイルカードは「{タイトル}、{状態}、{日時}、{長さ}」を1つのラベルとして読み上げ、内部要素を分割して読ませない。
- カード内の … Menu はカードとは独立したボタンとして読み上げる。
- AI コンポーザーが常駐するため、VoiceOver の読み上げ順はヘッダー → 一覧 → コンポーザー → NativeTabs とする。
- FAB には「作成メニューを開く」の `accessibilityLabel` を設定し、Menu 展開時は最初のメニュー項目へフォーカスを移す。
- すべてのタップ領域は 44pt 以上とする。
- Dynamic Type 最大時もカードとコンポーザーの内容が切れず、操作領域が重ならないことを確認する。

## Copy

`docs/design/ux-copy.md` の既存文言に従う。

| 要素 | テキスト |
|---|---|
| 表示切替（ファイル） | ファイル |
| 表示切替（プロジェクト） | プロジェクト |
| コンポーザー placeholder | Ask anything... |
| FAB メニュー | 録音を開始 / インポート / オンライン会議 |
| 空状態（ファイル） | 最初の会議を録音しましょう |
| 空状態（プロジェクト） | プロジェクトはまだありません |

## Acceptance criteria

1. AI コンポーザーは一覧をスクロールしても位置が変わらない。
2. コンポーザーは NativeTabs の一段上に表示され、重ならない。
3. スクロール末尾のカードは、コンポーザー高・NativeTabs 高・安全領域を合算した実測値の bottom padding により隠れない。
4. `minimizeBehavior="onScrollDown"` でタブバーが縮んでも、コンポーザーは NativeTabs に追随する。
5. ヘッダー Select の切替で FlashList のデータが入れ替わる。
6. FAB の Menu は録音開始・インポート・オンライン会議の3項目を表示し、背景を減光する。
7. iOS 26 未満および Android では GlassView ではなく BlurView を使う。
8. カード押下のフィードバックは `scale: 1.0 → 0.98` である。
9. Dynamic Type 最大時もレイアウトが破綻しない。
