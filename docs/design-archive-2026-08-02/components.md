# 共通コンポーネント設計

作成日: 2026-07-26
方針: **過度な抽象化を避ける。** HeroUI 標準で足りるものはラップしない。

## 分類

| 種別 | 定義 | 数 |
|---|---|---|
| HeroUI 標準をそのまま使う | ラッパーを作らない | 多数 |
| HeroUI をラップする | Memora の情報構造を固定するため | 9 |
| 完全な独自実装 | HeroUI に該当が無い | 5 |

**ラッパーを作る基準**: 同じ組み合わせが3箇所以上で使われ、かつ情報構造を統一したい場合のみ。

---

## HeroUI をラップするコンポーネント（9）

### FileCard

- **責務**: 会議1件の要約表示
- **基盤**: `Card`（`.Header/.Title/.Description/.Body/.Footer`）
- **props**: `meeting`, `onPress`, `onLongPress?`, `showProject?`, `showStatus?`
- **variants**: `default` / `compact`（ホームの最近3件用）
- **states**: 通常 / 処理中 / 失敗
- **a11y**: カード全体を1つの意味単位として読み上げる
- **使用画面**: ホーム、プロジェクト表示、検索結果
- **使用禁止**: 会議以外のエンティティに流用しない

### TaskItem

- **責務**: タスク1件の表示と完了操作
- **基盤**: `ListGroup.Item` + `Checkbox`
- **props**: `task`, `onToggle`, `onPress`, `onSourcePress`, `showSource?`
- **variants**: `default` / `compact`
- **states**: 未完了 / 完了 / 期限切れ / 保存中
- **a11y**: `accessibilityRole="checkbox"`、読み上げに出典会議を含む
- **使用画面**: タスク、ホーム、会議詳細、プロジェクト詳細
- **使用禁止**: 出典会議が無いタスクでも `showSource` を true にしない

### StatusChip

- **責務**: 処理状態の表示
- **基盤**: `Chip`
- **props**: `status`, `size?`
- **variants**: `idle` / `processing` / `success` / `warning` / `error` / `recording`
- **a11y**: **色だけで状態を表さない。** 必ずテキストを含む
- **使用画面**: 全般
- **使用禁止**: 状態以外のラベル表示に使わない（それは `Chip` を直接使う）

### SectionHeader

- **責務**: セクション見出し + 補助操作
- **基盤**: `Text`
- **props**: `title`, `count?`, `action?`（「すべて見る」等）
- **a11y**: `accessibilityRole="header"`
- **使用画面**: タスク、要約、設定、会議詳細、プロジェクト詳細
- **使用禁止**: `ListGroup` を見出しに使わない（行区切りを強制するため）

### EmptyState

- **責務**: 空状態の表示と次の行動の提示
- **基盤**: `Card`（`.Title/.Description/.Footer`）+ `Button`
- **props**: `title`, `description`, `action?`, `icon?`
- **a11y**: 見出しレベルを設定
- **使用画面**: 全一覧画面
- **使用禁止**: **CTA の無い空状態を作らない。** 必ず次の行動を示す

### ErrorState

- **責務**: 失敗の表示と回復手段の提示
- **基盤**: `Alert`（`.Indicator/.Title/.Description`）+ `Button`
- **props**: `title`, `description`, `onRetry?`, `onDismiss?`
- **a11y**: `accessibilityLiveRegion="assertive"`
- **使用画面**: 全般
- **使用禁止**: **再試行または代替手段の無いエラー表示を作らない**

### SpeakerBadge

- **責務**: 話者の識別表示
- **基盤**: `Chip`
- **props**: `speaker`, `colorIndex`
- **a11y**: **色だけで話者を区別しない。** 名前を必ず表示
- **使用画面**: 文字起こし
- **使用禁止**: 話者判別が無い場合は表示しない

### SearchResultItem

- **責務**: 検索結果1件（一致箇所のハイライト付き）
- **基盤**: `ListGroup.Item`
- **props**: `result`, `query`, `onPress`
- **variants**: `meeting` / `transcript` / `task`
- **a11y**: ハイライトを色だけに依存しない
- **使用画面**: 検索

### AIComposer

- **責務**: 全タブで常駐する AI チャット入力
- **基盤**: `TextArea` + `Button isIconOnly` + `Select`。外枠は `GlassContainer` / `GlassView`、フォールバックは `BlurView`
- **props**: `value`, `onChangeText`, `onAttach`, `model`, `onModelChange`, `onVoiceInput`, `onSend`, `projectId?`
- **配置**: `NativeTabs.BottomAccessory`。一覧スクロール領域には含めない
- **プロジェクト表示**: 上部にプロジェクト Select を追加し、選択肢は Bottom Sheet で表示
- **a11y**: 添付・音声・送信の各ボタンは内容を示す label を持つ

---

## 完全な独自実装（5）

HeroUI に該当コンポーネントが存在しないもの。

### ProgressBar

- **責務**: 決定的進捗の表示
- **理由**: **HeroUI Native に `Progress` が存在しない**（v1.0.3 で確認済み）
- **実装**: View + Reanimated。`transform: scaleX` でアニメート
- **props**: `value`（0-1）, `label?`, `showPercentage?`
- **a11y**: `accessibilityRole="progressbar"` + `accessibilityValue`
- **使用画面**: 処理中、設定（容量）
- **使用禁止**: **進捗が取得できない処理に使わない。** その場合は `Spinner`

### RecordingWaveform

- **責務**: 録音中の音声レベル可視化
- **理由**: Memora 固有。録音されていることを直感的に伝える
- **実装**: Reanimated（または Skia）
- **props**: `levels`, `isActive`
- **a11y**: 装飾なので `accessibilityElementsHidden`。**Reduce Motion 時は静的バーに切替**
- **使用画面**: 録音中

### RecordingTimer

- **責務**: 経過時間表示
- **理由**: 等幅数字が必要（数字が変わるたびに幅が動くのを防ぐ）
- **基盤**: `Text`（`mono` トークン）
- **props**: `seconds`, `isPaused?`
- **a11y**: 「録音時間 12分34秒」の形。更新頻度を抑える
- **使用画面**: 録音中、グローバル録音バー

### TranscriptSegment

- **責務**: 文字起こしの1発言単位
- **理由**: 再生位置連動、話者表示、タップシークの組み合わせが Memora 固有
- **基盤**: `Surface` + `PressableFeedback` + `Text`（`transcript` トークン）
- **props**: `segment`, `isActive`, `showSpeaker`, `onPress`, `onLayout`
- **a11y**: 「{話者}、{時刻}、{本文}」を1単位で読み上げ
- **使用画面**: 文字起こし
- **注意**: `onLayout` でオフセットを記録する（自動スクロールに必要）

### RecordingStatusBar

- **責務**: グローバルな録音・処理状態の表示
- **基盤**: `Surface` + `PressableFeedback` + `ProgressBar`
- **props**: `mode`（recording / processing）, `data`, `onPress`, `onStop?`, `onPause?`
- **a11y**: `accessibilityLiveRegion="polite"`
- **使用画面**: 全タブ（`(tabs)/_layout.tsx` に常駐）
- **注意**: 録音中は録音バーが優先。処理中バーは表示しない

---

## ラッパーを作らないもの

以下は HeroUI 標準を直接使う。ラッパーを作ると抽象化が過剰になる。

| 用途 | 使用するもの |
|---|---|
| ボタン | `Button` |
| 入力 | `TextField` + `Input` / `TextArea` |
| 検索 | `SearchField` |
| トグル | `Switch` |
| タブ切替 | `Tabs` |
| シート | `BottomSheet` |
| 確認 | `Dialog` |
| 設定行 | `ListGroup.Item` |
| 区切り | `Separator` |
| スケルトン | `Skeleton` / `SkeletonGroup` |
| 通知 | `Toast` |
| 待機 | `Spinner` |

## 廃止するコンポーネント

現行から削除するもの。

| 現行 | 理由 |
|---|---|
| `FileCard` | 名称を維持し、HeroUI `Card` の compound slots へ内部実装を移行 |
| `SegmentedControl` | `Tabs` を直接使う |
| `SheetCard` | `BottomSheet.Content` へ統合 |
| `Section` | `SectionHeader` へ縮小 |
| `V6FloatingTabBar` | 廃止。`NativeTabs` と中央 FAB の `Menu` へ移行 |
| `TabBar` | 廃止。`NativeTabs` を採用し、中央 FAB は `Menu` へ移行 |
| `TranscriptionProgressCard` | `ProcessingIndicator` + `ProgressBar` へ分解 |
| `StatusPill` | `StatusChip` へ改名 |
| `FileDetailGeneratingSkeleton` | `SkeletonGroup` を直接使う |
| `MotionPressable` | `PressableFeedback` があるため素の Pressable 用途のみに限定 |
