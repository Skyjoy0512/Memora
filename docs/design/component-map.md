# Memora コンポーネント対応表（Component Map）

- 更新日: 2026-08-02
- 位置付け: デザインターゲットのコンポーネント契約。既存IAは不変
  （[`information-architecture.md`](./information-architecture.md)）。
- 関連: [`MEMORA_DESIGN.md`](./MEMORA_DESIGN.md) / [`screen-patterns.md`](./screen-patterns.md) / [`prohibitions.md`](./prohibitions.md)

## 1. 依存状態（正確な記述）

- **HeroUI Native は `apps/mobile-expo/package.json` に導入済み（1.0.8）**。
  Uniwind 1.10.0 / tailwindcss 4.x / tailwind-merge / tailwind-variants も導入済みで、
  `metro.config.js` + `global.css` + `HeroUINativeProvider`（`heroui-native/provider`）
  の基盤は有効。本稿の HeroUI Native 対応表はこの基盤の上で画面単位に適用する契約。
- 既存コードの `src/design/tokens.ts` は
  [`apps/mobile-expo/src/theme/tokens.ts`](../../apps/mobile-expo/src/theme/tokens.ts) を
  正本とする互換アダプタへ置換済み（import パスは旧パスのまま動作）。
- ナビゲーションは Expo Router の `NativeTabs`（`expo-router/unstable-native-tabs`）
  と Stack を使用する（[`navigation.md`](./navigation.md) 準拠）。
- ガラス表現は iOS 26 以上の `@callstack/liquid-glass` のみ。非対応OS
  （iOS 26未満・Android）・Reduce Transparency・利用不能時は、意味論色
   `glassFallback` / `glassBorderFallback` を使う不透明な Surface/View へ
   切替える。
- イベントは **`onPress`** を使用し、`onClick`（Web）は使わない。
- IA文書内の旧ビジュアル実装記述より、本稿および [`MEMORA_DESIGN.md`](./MEMORA_DESIGN.md) の
   技術契約が優先される。

## 2. ナビゲーション（Expo Router）

| 目的 | 実装 | 補足 |
|---|---|---|
| ボトムタブ | `NativeTabs`（Trigger / Icon） | ホーム / タスク / AI / 設定。独自 tabBar を作らない |
| 中央FAB | HeroUI Native `Menu`（`Trigger asChild` + `Button isIconOnly`） | タブではない。presentation=popover / placement=top / align=center |
| Stack push | Expo Router `Stack` | file/[id] など |
| モーダル | Expo Router modal / fullScreenModal | record / search / import / online meeting / auth |
| 常駐AIコンポーザー | `NativeTabs.BottomAccessory` + Glass 外枠 | TextArea + 添付/送信 Button + Select（Auto / モデル） |

## 3. HeroUI Native マッピング（ターゲット契約）

`heroui-native` v1.0.8 の確認済みコンポーネントを用途別に整理する。

### 3.1 一覧・行（リスト）

| 用途 | コンポーネント | 状態 | アクセシビリティ |
|---|---|---|---|
| ファイル / プロジェクト / タスクの行 | `ListGroup` または `Surface` + `Separator` + `Text` + `Chip` | pressed（行フィードバック）/ selected（トナル）/ loading（行スケルトン） | 行全体を1つの操作要素に結合、`accessibilityRole="button"`、state をラベルで補足 |
| 設定の行 | `ListGroup` + `ControlField` + `Switch` / `Select` | disabled / selected | Switch にラベル、trait `switch` |

### 3.2 操作・入力

| 用途 | コンポーネント | 状態 | アクセシビリティ |
|---|---|---|---|
| 主要操作 | `Button`（primary / secondary / tertiary / outline / ghost / danger / danger-soft） | pressed / disabled / loading（`Spinner` 併用）/ focused | `accessibilityLabel`、状態を文字で補足 |
| アイコン操作 | `Button isIconOnly` + 添付`Icon` | pressed / disabled | 必ず `accessibilityLabel` |
| 押下フィードバック | `PressableFeedback` | pressed / focused | — |
| テキスト入力 | `Input` / `TextArea` / `TextField` / `SearchField` | focused / disabled / error（`FieldError` + `Description`） | `accessibilityLabel`、ラベルは `Label` で紐付け |
| 選択 | `Select` / `RadioGroup` / `Checkbox` | selected / disabled | 選択状態を trait で表現、選択肢を VoiceOver に列挙 |

### 3.3 状態・フィードバック

| 用途 | コンポーネント | 状態 | アクセシビリティ |
|---|---|---|---|
| 状態ラベル | `Chip`（常にテキスト併記） | — | 状態をテキストで伝える。色だけにしない |
| 警告 | `Alert` | — | 重要度と対処をテキストで示す |
| 処理中（不確定） | `Spinner` | — | `accessibilityLabel`（例: 「文字起こし中」） |
| 処理中（形が既知） | `Skeleton` / `SkeletonGroup` | — | `accessibilityHidden` またはラベルで代替 |
| 通知 | `Toast` | — | 短い完了通知のみ。重要エラーは `Alert` |
| セクション境界 | `Separator`（ヘアライン） | — | 装飾要素は `accessibilityElementsHidden` |

### 3.4 オーバーレイ

| 用途 | コンポーネント | 補足 |
|---|---|---|
| 作成メニュー（FAB） | `Menu`（`Trigger asChild`）+ `Menu.Portal` / `Menu.Overlay` / `Menu.Content` | placement=top / align=center |
| 選択肢を広げて選ぶ | `BottomSheet` | プロジェクト切替、モデル選択等 |
| 確認・破壊的操作 | `Dialog` | 危険操作の確認 |
| 文脈操作 | `Popover` | 行の詳細アクション等 |
| 要素の出し入れ | `Accordion` | 要約 / 詳細の折りたたみ（利用は控えめに） |

### 3.5 装飾・補助

| 用途 | コンポーネント | 補足 |
|---|---|---|
| アイコン表示 | アイコンライブラリ + `Text` | `icon` トークン（14〜28） |
| アバター | `Avatar` | 話者 / プロジェクト表示 |
| タグ集合 | `TagGroup` | メタデータの列挙 |
| スクロール端の減衰 | `ScrollShadow` | 一覧の上下端 |
| 範囲入力 | `Slider` | 再生位置等（任意） |

### 3.6 未使用候補（現状マッピングなし）

`InputOTP` / `RadioGroup`（将来の選択UIに応じて）、`CloseButton`
（カスタムクローズで代替可）。**`Card` は §5 の制約に従う**。

## 4. Liquid Glass ラッパー

| 用途 | iOS 26+ | フォールバック（非対応OS・Reduce Transparency・利用不能時） |
|---|---|---|
| ナビゲーション / BottomAccessory 外枠 | `LiquidGlassContainerView` / `LiquidGlassView` | 不透明な `Surface` / `View`（`glassFallback` + `glassBorderFallback`） |
| 中央FAB（作成メニュー） | `LiquidGlassView` | 不透明な `Surface` / `View`（`glassFallback` + `glassBorderFallback`） |
| 主要録音コントロール | `LiquidGlassView` | 不透明な `Surface` / `View`（`glassFallback` + `glassBorderFallback`） |

ガラス上のテキストは `foregroundPrimary` で可読性を保証する。

## 5. 独自プロダクトコンポーネント

HeroUI Native に存在しない Memora 固有のUI。

| コンポーネント | 責務 | 状態・アクセシビリティ |
|---|---|---|
| `RecordingWaveform` | 録音中の波形可視化 | `dataViz.waveform`。録音中は recording 色 + アニメーション。VoiceOver はラベル + `RecordingTimer` で代替 |
| `RecordingTimer` | 経過時間表示 | タイマーはフォント等幅（mono）または数値整形。音声で読み上げ |
| `AudioTimeline` | 再生 / シーク位置とセグメント表示 | 決定性プログレス。スクラブ時は値と位置を両方示す |
| `TranscriptSegment` | 話者ラベル + テキスト + 時刻 | 話者名・時刻はメタデータスタイル。選択でハイライト |
| `ProcessingRail` / `ProgressBar` | 文字起こし・要約の決定性進捗 | **HeroUI Native に Progress がないため独自実装**。形が未知なら `Spinner` / `SkeletonGroup` |
| `RecordingControlFab` | 録音開始・停止の主操作 | 56pt タップ領域。録音中は「停止」に変化。赤 + 波形 + ラベルで状態を三重に伝える |

## 6. 状態とアクセシビリティの共通期待値

全コンポーネント共通の期待値（[`MEMORA_DESIGN.md`](./MEMORA_DESIGN.md) §9 / §11 準拠）。

- **pressed**: 押下フィードバック（トナル反転 or `opacity.pressed` + 微スケール）
- **focused**: `focus` 色のフォーカスリング（キーボード / VoiceOver カーソル）
- **selected**: `selection` / `selectionForeground` + 非色の手掛かり
- **disabled**: `opacity.disabled`（0.38）、操作不能、フィードバックなし
- **loading**: `Spinner`（不確定） / `SkeletonGroup`（形が既知） / `ProcessingRail`（決定性）
- 状態は**色だけにしない**。VoiceOver は状態を trait / ラベルで伝える。

## 7. Card 使用の明示的制約

- **リスト行を `Card` で表現しない**。ファイル・プロジェクト・タスクの行は
  `ListGroup` または `Surface` + `Separator` を使う（[`prohibitions.md`](./prohibitions.md) §5）。
- `Card` は「境界を持った独立した対象物」に限定する（例: ファイル詳細の要約ブロック等）。
  装飾的なカード連打（cards-inside-cards）を禁止する。
- カードには `Card.Header` / `Card.Body` / `Card.Title` / `Card.Description` /
  `Card.Footer` を使う。

## 8. 依存導入時のマイグレーション

1. `heroui-native` v1.0.8 と Uniwind を導入済み（Provider は RootLayout に導入済み）。
2. `src/theme/tokens.ts` の意味論トークンを HeroUI Native のセマンティックロールへ
   マップ済み（`global.css` の `@layer theme` で `@variant light` / `@variant dark` を上書き）。
   独立した変数レイヤーを作らない。
3. 既存 `src/design/tokens.ts` を `src/theme/tokens.ts` を正本とする互換アダプタへ
   置換済み（import パスは旧パスのまま）。
4. 画面単位で置換し、状態・アクセシビリティ期待値を満たすことを確認する。
