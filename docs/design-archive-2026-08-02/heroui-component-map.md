# HeroUI Native コンポーネントマッピング

作成日: 2026-07-26
参照: `heroui-native` 公式 Skill（v1.0.3 ドキュメント / 導入版 `heroui-native@1.0.6`）

## 実在確認済みコンポーネント（39件）

`node .agents/skills/heroui-native/scripts/list_components.mjs` で確認。

```
Accordion, Alert, Avatar, BottomSheet, Button, Card,
Checkbox, Chip, CloseButton, ControlField, Description, Dialog,
FieldError, Input, InputGroup, InputOTP, Label, LinkButton,
ListGroup, Menu, Popover, PressableFeedback, RadioGroup, ScrollShadow,
SearchField, Select, Separator, Skeleton, SkeletonGroup, Slider,
Spinner, Surface, Switch, Tabs, TagGroup, Text,
TextArea, TextField, Toast
```

**存在しないもの（設計上の重要な制約）**
- `Progress` / `ProgressBar` — 決定的進捗の表示手段が無い。**独自実装が必要**
- `Badge` — `Chip` で代替する
- `Fab` — `Button` + `PressableFeedback` で構成する
- `SegmentedControl` — `Tabs` で代替する
- `Toolbar` / `NavBar` — Expo Router のヘッダーまたは `Surface` で構成する

## 確認済み slot 構造

記憶で推測せず、Skill から取得した実際の値。

| コンポーネント | slot |
|---|---|
| `Card` | `.Header` `.Title` `.Description` `.Body` `.Footer` |
| `ListGroup` | `.Item` `.ItemContent` `.ItemTitle` `.ItemDescription` `.ItemPrefix` `.ItemSuffix` |
| `BottomSheet` | `.Portal` `.Overlay` `.Content` `.Title` `.Description` `.Trigger` `.Close` |
| `Dialog` | `.Portal` `.Overlay` `.Content` `.Title` `.Description` `.Trigger` `.Close` |
| `Tabs` | `.List` `.Trigger` `.Label` `.Indicator` `.Content` `.ScrollView` `.Separator` |
| `Alert` | `.Indicator` `.Content` `.Title` `.Description` |
| `SearchField` | `.Group` `.SearchIcon` `.Input` `.ClearButton` |
| `Select` | `.Trigger` `.Value` `.TriggerIndicator` `.Portal` `.Overlay` `.Content` `.Item` `.ItemLabel` `.ItemIndicator` |
| `Menu` | `.Trigger` `.Portal` `.Overlay` `.Content` `.Item` |
| `Button` | `isIconOnly` を指定できる |

**root が状態・テーマ・コンテキストを担い、compound slot が内部構造を担う。** root だけ使って中身を自前で組むと、コンテキストが供給されず破綻する。

## 用途別マッピング

### 全体・共通

| UI 用途 | HeroUI Native | カスタム | 理由 |
|---|---|---|---|
| 画面の面 | `Surface` | 不要 | 階層は `surface` / `surface-secondary` / `surface-tertiary` で表現 |
| 本文・見出し | `Text` | 不要 | テーマのタイポグラフィに従う |
| 補足説明 | `Description` | 不要 | 意味的に補足を表す |
| 区切り | `Separator` | 不要 | |
| 主要 CTA | `Button` | 不要 | semantic variant を使用 |
| テキストリンク的操作 | `LinkButton` | 不要 | |
| 押下フィードバック | `PressableFeedback` | 不要 | 既存 `MotionPressable` は素の Pressable 用に限定 |
| 状態表示 | `Chip` | 不要 | 色 + テキストで色依存を回避 |
| 読み込み | `Spinner` | 不要 | 非決定的な待機のみ |
| スケルトン | `Skeleton` / `SkeletonGroup` | 不要 | 実体と同形にする |
| 空・エラー | `Card` + `Alert` | 不要 | |
| 完了通知 | `Toast` | 不要 | |
| スクロール端 | `ScrollShadow` | 不要 | 硬い区切り線の代替 |

### ナビゲーション

| UI 用途 | HeroUI Native | カスタム | 理由 |
|---|---|---|---|
| Bottom Tab バー | Expo Router `NativeTabs` | 不要 | `NativeTabs.Trigger` / `.Icon` を使い、`minimizeBehavior="onScrollDown"` を指定 |
| 中央 FAB | `Menu.Trigger asChild` + `Button isIconOnly` | 不要 | タブではない。`.Portal/.Overlay/.Content` に録音開始・インポート・オンライン会議を表示 |
| グローバル録音バー | `Surface` をラップ | **一部必要** | 経過時間と操作を持つ Memora 固有 UI |
| 画面内タブ切替 | `Tabs` | 不要 | `.List` `.Trigger` `.Indicator` を使用 |
| ヘッダー表示切替 | `Select` | 不要 | ファイル / プロジェクト。`.Portal/.Overlay/.Content` の popover を使う |
| ヘッダーアイコン | `Button isIconOnly` | 不要 | `expo-symbols` の `SymbolView` を子に置き、最大2個に限定 |

### 一覧・カード

| UI 用途 | HeroUI Native | カスタム | 理由 |
|---|---|---|---|
| 会議カード | `Card` | ラップ | `.Header/.Title/.Description/.Body/.Footer` で構成し、Memora の情報階層を固定する |
| 設定行 | `ListGroup` | 不要 | `.Item/.ItemPrefix/.ItemTitle/.ItemSuffix`。行区切りが意味を持つ |
| タスク行 | `ListGroup` + `Checkbox` | ラップ | 出典会議の表示を `.ItemDescription` に |
| プロジェクトカード | `Card` | ラップ | |
| 検索結果 | `ListGroup` | ラップ | 一致箇所のハイライトが必要 |
| セクション見出し | `Text` | 不要 | `ListGroup` は行区切りを強制するため見出しには使わない |

### 入力

| UI 用途 | HeroUI Native | カスタム | 理由 |
|---|---|---|---|
| 単一行入力 | `TextField` + `Input` | 不要 | ラベル・エラーは `Label` / `FieldError` |
| 複数行入力 | `TextArea` | 不要 | メモ・Ask の質問 |
| 検索 | `SearchField` | 不要 | `.Group/.SearchIcon/.Input/.ClearButton` |
| 確認コード | `InputOTP` | 不要 | 認証フロー |
| トグル | `Switch` | 不要 | |
| チェック | `Checkbox` | 不要 | タスク完了 |
| 単一選択 | `RadioGroup` | 不要 | AI プロバイダ選択など |
| ドロップダウン選択 | `Select` | 不要 | |
| AI コンポーザー | `TextArea` + `Button isIconOnly` + `Select` | `AIComposer` | `NativeTabs.BottomAccessory` に常駐。GlassView / BlurView の外枠を持つ |
| スライダー | `Slider` | 不要 | **再生シークのみ**。進捗表示に流用しない |

### オーバーレイ

| UI 用途 | HeroUI Native | カスタム | 理由 |
|---|---|---|---|
| 補助操作 | `BottomSheet` | 不要 | `.Portal/.Overlay/.Content/.Title` |
| 破壊的操作の確認 | `Dialog` | 不要 | 削除・破棄 |
| 少数の選択肢 | `Menu` | 不要 | 並び替え・フィルタ |
| 補足情報 | `Popover` | 不要 | |
| 折りたたみ | `Accordion` | 不要 | 要約の詳細など |
| タグ群 | `TagGroup` | 不要 | 検索対象の絞り込み |

## Memora 固有コンポーネント（独自実装）

HeroUI に該当が無く、Memora の中核価値に直結するもの。

| コンポーネント | 責務 | 基盤 | 理由 |
|---|---|---|---|
| **`ProgressBar`** | 決定的進捗の表示 | View + Reanimated | **HeroUI に `Progress` が存在しない。** 文字起こし・モデルダウンロード・書き出しで必須 |
| **`RecordingWaveform`** | 録音中の音声レベル可視化 | Skia または View + Reanimated | 録音中であることを直感的に伝える。Memora 固有 |
| **`RecordingTimer`** | 経過時間表示 | `Text` | 等幅数字でガタつきを防ぐ |
| **`AudioTimeline`** | 再生位置と文字起こしの対応表示 | `Slider` + 独自 | シークは `Slider`、セグメント対応は独自 |
| **`TranscriptSegment`** | 話者・時刻・本文の1単位 | `Surface` + `Text` | 再生位置連動、タップでシーク |
| **`SpeakerBadge`** | 話者ラベル | `Chip` をラップ | 話者ごとの色分けが必要 |
| **`RecordingStatusBar`** | グローバル録音状態 | `Surface` + `PressableFeedback` | 全画面に常駐 |
| **`TabBar`** | Bottom Tab + 中央 CTA | `Surface` + `PressableFeedback` | Expo Router の `tabBar` として必要 |

**独自実装は上記8つに限定する。** これ以外は HeroUI 標準で構成する。

## OS ネイティブ UI を使うもの

| 用途 | 手段 | 理由 |
|---|---|---|
| ファイル選択 | `expo-document-picker` | OS 標準が最も信頼できる |
| 写真選択 | `expo-image-picker` | 同上 |
| 共有 | RN `Share` | OS の共有シートを使う |
| 権限要求 | OS ダイアログ | カスタム不可 |
| ヘッダー | Expo Router のネイティブヘッダー | 戻るジェスチャを維持 |

## 禁止事項

- `@heroui/react`（HeroUI Web）の使用
- HeroUI Web の API を React Native へ流用すること
- `onClick`（React Native は `onPress`）
- DOM 要素の前提
- NativeWind 前提の設計（本プロジェクトは **Uniwind**）
- HeroUI Native 以外の総合 UI ライブラリの併用
- **実在を確認していないコンポーネントを仕様書に書くこと**

## 移行時の注意

現状 `src/components/` に存在する以下は、新設計では役割が変わる。

| 現行 | 新設計での扱い |
|---|---|
| `FileCard` | 名称を維持。HeroUI `Card` の compound slots へ段階移行 |
| `SegmentedControl` | `Tabs` を直接使用。ラッパー廃止 |
| `SheetCard` | `BottomSheet.Content` へ統合。ラッパー廃止 |
| `StatusPill` | `StatusChip` へ改名。`Chip` をラップ |
| `Section` | `SectionHeader`（`Text` のみ）へ縮小 |
| `V6FloatingTabBar` | `TabBar` へ改名。中央 CTA を明示的に設計 |
| `TranscriptionProgressCard` | `ProcessingIndicator` へ。独自 `ProgressBar` を使用 |
