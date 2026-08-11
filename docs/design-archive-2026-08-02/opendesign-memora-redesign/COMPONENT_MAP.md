# COMPONENT_MAP.md — コンポーネント一覧と実装判断

> **ステータス**: 設計フェーズ / Codex 実装用仕様
> **更新日**: 2026-07-14

---

## 読み方

各コンポーネントの判断：
- ✅ **維持** — 既存のまま使う（クラス名やフォーマットの統一は除く）
- 🔄 **改修** — 機能は維持、Props/スタイル/状態を拡張
- 🆕 **新規** — 新しく作る
- ❌ **削除** — 使わなくなる（ファイルは残し、参照を外す）

---

## 1. 画面ラッパー・シェル

### Screen
- **パス**: `src/components/Screen.tsx`
- **判断**: 🔄 改修
- **理由**: 基本構造は維持。`subtitle` の型を `ReactNode` に拡張し、`headerAccessory` の位置を調整。`contentContainerStyle` に `paddingBottom: 112` がハードコードされているのを `safeAreaInsets.bottom` ベースに変更。
- **変更内容**:
  - `titleContent` がある場合のタイトル行レイアウトを改善
  - `footerAccessory` の `KeyboardAvoidingView` との相互作用を整理
  - ダークモード対応（`useColors()` フックに切り替え）
- **依存**: `react-native-safe-area-context`, `design/tokens`

### Section
- **パス**: `src/components/Section.tsx`
- **判断**: ✅ 維持（スタイル微調整のみ）
- **理由**: シンプルなラッパーで変更不要。`colors` 参照を `useColors()` に切り替え。

---

## 2. ナビゲーション

### V6FloatingTabBar
- **パス**: `src/components/V6FloatingTabBar.tsx`
- **判断**: 🔄 改修
- **理由**: 基本的なフローティングタブバー + FAB の構造は優れている。FABメニューを3項目から「録音」「読み込み」の2項目に整理。liquid-glass 依存は維持。
- **変更内容**:
  - FABメニュー項目を整理（会議キャプチャーを削除、録音を最優先に）
  - メニューアニメーションを `LayoutAnimation` に統一
  - 録音中はFABのアイコンを変化（+ → 録音中ドット）
  - タブアイコンを `Ionicons` の `outline`/`filled` で統一
- **依存**: `@callstack/liquid-glass`, `react-native-safe-area-context`, `expo-document-picker`

---

## 3. 状態表示

### StateViews（LoadingState / EmptyState / ErrorState）
- **パス**: `src/components/StateViews.tsx`
- **判断**: 🔄 改修
- **理由**: 基本パターンは良いが、以下の拡張が必要：
- **変更内容**:
  - `EmptyState` に `actionLabel` と `onAction` Propsを追加（CTAボタン表示）
  - `EmptyState` に `illustration` Propsを追加（大きめのアイコン or イラスト表示用）
  - `LoadingState` を `SkeletonVariant` に置き換え可能にする
  - 全コンポーネントに `accessibilityLabel` / `accessibilityRole` を適切に設定
  - ダークモード対応
- **新規追加**: `SkeletonCard` — カード形状のスケルトンローディング
- **新規追加**: `OfflineBanner` — オフライン状態バナー

### StatusPill
- **パス**: `src/components/StatusPill.tsx`
- **判断**: 🔄 改修
- **理由**: ステータス表示のバリエーションを増やす。
- **変更内容**:
  - `variant`: `'ready' | 'transcribing' | 'failed' | 'summarized' | 'processing'`
  - 各バリアントに対応する色とラベルを定義
  - アニメーション対応（処理中はパルス）
- **日本語ラベル**: 準備完了 / 文字起こし中 / 失敗 / 要約済 / 処理中

---

## 4. リスト・カード

### V6AudioFileRow → FileCard（改名）
- **パス**: `src/components/V6AudioFileRow.tsx` → 新規 `src/components/FileCard.tsx`
- **判断**: 🆕 新規（旧コンポーネントは ❌ 削除）
- **理由**: 現在の `V6AudioFileRow` はタイトル・メタ情報・ステータスのみで、要約プレビューやアクションメニューがない。情報量を増やし、カード型に刷新。
- **Props**:
  ```ts
  type FileCardProps = {
    file: AudioFile;
    onPress: () => void;
    onMore: () => void;
    showSummary?: boolean;     // 要約の先頭行を表示するか
  };
  ```
- **レイアウト**: 72px高、左アイコン＋中央テキスト2行＋右ステータスピル＋右端「⋯」
- **依存**: `types/memora`, `design/tokens`

### AudioFileCard
- **パス**: `src/components/AudioFileCard.tsx`
- **判断**: ❌ 削除（`FileCard` に統合）

### DateSeparator（新規）
- **パス**: 新規 `src/components/DateSeparator.tsx`
- **判断**: 🆕 新規
- **理由**: リスト内の日付区切りを再利用可能なコンポーネントに。
- **Props**:
  ```ts
  type DateSeparatorProps = {
    date: string;  // 表示用日付文字列（例: "7月10日（木）"）
  };
  ```

### FileCardSkeleton（新規）
- **パス**: 新規 `src/components/FileCardSkeleton.tsx`
- **判断**: 🆕 新規
- **理由**: 読み込み中のプレースホルダ。`FileCard` と同じ寸法で、シマーアニメーションを適用。
- **Props**:
  ```ts
  type FileCardSkeletonProps = {
    count?: number;  // 表示するスケルトン数（デフォルト: 5）
  };
  ```

---

## 5. シート・モーダル

### FloatingBottomSheet
- **パス**: `src/components/FloatingBottomSheet.tsx`
- **判断**: ✅ 維持
- **理由**: シンプルなボトムシートラッパー。変更不要。

### SheetCard
- **パス**: `src/components/SheetCard.tsx`
- **判断**: ✅ 維持
- **理由**: シート内のカードコンテナ。変更不要（ダークモード対応のみ）。

---

## 6. 録音・キャプチャ

### CaptureFlowProvider
- **パス**: `src/features/capture/CaptureFlowProvider.tsx`
- **判断**: 🔄 改修
- **理由**: 録音フローを1画面に統合するため、内部状態とレンダリングを大幅に簡素化。
- **変更内容**:
  - `RecordingOverlay` にクイックメモ欄・タイトル入力・テンプレート選択を統合
  - `GenerateOverlay` を削除（録音停止後は自動保存・自動処理）
  - `GenerationOverlay` は Dynamic Island Pill の詳細表示として最小化
  - 状態機械の簡素化: `idle → recording → saving → completed`
- **注意**: ネイティブブリッジの境界は変更しない。録音・保存の API 呼び出しは既存のまま。

### PlayerBar
- **パス**: `src/components/PlayerBar.tsx`
- **判断**: 🔄 改修
- **理由**: デザインリフレッシュ。基本機能は維持。
- **変更内容**:
  - 高さ 56px に統一
  - シークバーの視認性向上
  - 速度切替ラベル表示
  - ダークモード対応

### TranscriptionProgressCard
- **パス**: `src/components/TranscriptionProgressCard.tsx`
- **判断**: 🔄 改修
- **理由**: 進捗表示の視認性向上。
- **変更内容**:
  - プログレスバーのデザインを `colors.accent` ベースに
  - フェーズ表示を日本語化
  - エラー時の再試行導線を明確に

---

## 7. Ask AI

### ChatThread（新規）
- **パス**: 新規 `src/components/ChatThread.tsx`
- **判断**: 🆕 新規
- **理由**: 会話スレッドを単独のスクロール可能コンポーネントに。
- **Props**:
  ```ts
  type ChatThreadProps = {
    messages: AskMessage[];
    isAnswering: boolean;
  };
  ```

### ChatBubble（新規）
- **パス**: 新規 `src/components/ChatBubble.tsx`
- **判断**: 🆕 新規
- **理由**: ユーザー発言とAI回答で異なるスタイルの吹き出し。
- **Props**:
  ```ts
  type ChatBubbleProps = {
    message: AskMessage;
    onSourcePress?: (source: string) => void;
    onCopy?: () => void;
    onTaskify?: () => void;
  };
  ```

### SourcePill（新規）
- **パス**: 新規 `src/components/SourcePill.tsx`
- **判断**: 🆕 新規
- **理由**: 回答の参照元を表示するタップ可能なピル。
- **Props**:
  ```ts
  type SourcePillProps = {
    source: string;      // ファイル名
    fileId?: string;     // タップ時に遷移するファイルID
    onPress?: () => void;
  };
  ```

### ScopeSelector（新規）
- **パス**: 新規 `src/components/ScopeSelector.tsx`
- **判断**: 🆕 新規
- **理由**: Ask AIのスコープ切替。セグメントコントロール型。
- **Props**:
  ```ts
  type ScopeSelectorProps = {
    scope: KnowledgeQueryScope;
    onScopeChange: (scope: KnowledgeQueryScope) => void;
    contextName?: string;  // プロジェクト名 or ファイル名
  };
  ```

### ChatInput（新規）
- **パス**: 新規 `src/components/ChatInput.tsx`
- **判断**: 🆕 新規
- **理由**: チャット入力エリア。送信ボタン・添付ボタン付き。
- **Props**:
  ```ts
  type ChatInputProps = {
    value: string;
    onChangeText: (text: string) => void;
    onSend: () => void;
    onAttach?: () => void;
    canSend: boolean;
    placeholder: string;
  };
  ```

### TypingIndicator（新規）
- **パス**: 新規 `src/components/TypingIndicator.tsx`
- **判断**: 🆕 新規
- **理由**: AI回答生成中のアニメーション表示。
- **Props**:
  ```ts
  type TypingIndicatorProps = {};
  ```

### SuggestionCard（新規）
- **パス**: 新規 `src/components/SuggestionCard.tsx`
- **判断**: 🆕 新規
- **理由**: 質問例の提案カード。
- **Props**:
  ```ts
  type SuggestionCardProps = {
    question: string;
    onPress: () => void;
  };
  ```

---

## 8. タスク

### TaskGroup
- **パス**: `src/screens/TasksScreen.tsx`（内部関数）
- **判断**: 🔄 改修 → 独立コンポーネントに
- **理由**: 再利用性のためファイル分離。
- **新規パス**: `src/components/TaskGroup.tsx`
- **Props**:
  ```ts
  type TaskGroupProps = {
    label: string;
    color?: string;
    tasks: Task[];
    onToggle: (id: string) => void;
    onOpenSource?: (fileId: string) => void;
  };
  ```

### TaskAddSheet（新規）
- **パス**: 新規 `src/components/TaskAddSheet.tsx`
- **判断**: 🆕 新規
- **理由**: タスク追加のボトムシート。期限選択・プロジェクト選択付き。

---

## 9. 設定

### SettingsGroup
- **パス**: `src/screens/SettingsScreen.tsx`（内部関数）
- **判断**: 🔄 改修 → 独立コンポーネントに
- **新規パス**: `src/components/SettingsGroup.tsx`

### SettingsToggle（新規）
- **パス**: 新規 `src/components/SettingsToggle.tsx`
- **判断**: 🆕 新規
- **理由**: トグルスイッチ付き設定行。
- **Props**:
  ```ts
  type SettingsToggleProps = {
    title: string;
    value: boolean;
    onValueChange: (value: boolean) => void;
    disabled?: boolean;
  };
  ```

### SettingsDestructive（新規）
- **パス**: 新規 `src/components/SettingsDestructive.tsx`
- **判断**: 🆕 新規
- **理由**: 破壊的操作の設定行（赤文字）。

---

## 10. 汎用UI

### SegmentedControl（新規）
- **パス**: 新規 `src/components/SegmentedControl.tsx`
- **判断**: 🆕 新規
- **理由**: 複数画面で使うセグメント切替。
- **Props**:
  ```ts
  type SegmentedControlProps<T extends string> = {
    segments: Array<{ key: T; label: string }>;
    selected: T;
    onSelect: (key: T) => void;
  };
  ```

### SearchBar（新規）
- **パス**: 新規 `src/components/SearchBar.tsx`
- **判断**: 🆕 新規
- **理由**: ホームの常時表示検索バー。
- **Props**:
  ```ts
  type SearchBarProps = {
    value: string;
    onChangeText: (text: string) => void;
    placeholder?: string;
    onFocus?: () => void;
    onBlur?: () => void;
  };
  ```

### AppIcon
- **パス**: `src/components/AppIcon.tsx`
- **判断**: ✅ 維持
- **理由**: アイコンラッパー。変更不要。

### TabBar（新規）
- **パス**: 新規 `src/components/TabBar.tsx`
- **判断**: 🆕 新規
- **理由**: ファイル詳細画面のタブ切替。
- **Props**:
  ```ts
  type TabBarProps<T extends string> = {
    tabs: Array<{ key: T; label: string }>;
    selected: T;
    onSelect: (key: T) => void;
  };
  ```

---

## 11. コンポーネント依存グラフ

```
Screen
├── SearchBar（新規）
├── SegmentedControl（新規）
├── FileCard（新規）
│   └── StatusPill（改修）
├── FileCardSkeleton（新規）
├── DateSeparator（新規）
├── StateViews（改修）
├── FloatingBottomSheet（維持）
│   └── SheetCard（維持）
├── PlayerBar（改修）
├── TabBar（新規）
├── ScopeSelector（新規）
├── ChatThread（新規）
│   ├── ChatBubble（新規）
│   │   └── SourcePill（新規）
│   └── TypingIndicator（新規）
├── ChatInput（新規）
├── SuggestionCard（新規）
├── TaskGroup（改修）
├── TaskAddSheet（新規）
├── SettingsGroup（改修）
├── SettingsRow（維持）
├── SettingsToggle（新規）
├── SettingsDestructive（新規）
└── TranscriptionProgressCard（改修）

CaptureFlowProvider（改修）
├── RecordingOverlay（改修）
└── DynamicIslandPill（維持改修）

V6FloatingTabBar（改修）
├── AppIcon（維持）
└── @callstack/liquid-glass（維持）
```

---

## 12. 実装ファイル一覧

### 新規作成

| ファイル | 種別 |
|---------|------|
| `src/components/SearchBar.tsx` | コンポーネント |
| `src/components/SegmentedControl.tsx` | コンポーネント |
| `src/components/TabBar.tsx` | コンポーネント |
| `src/components/FileCard.tsx` | コンポーネント |
| `src/components/FileCardSkeleton.tsx` | コンポーネント |
| `src/components/DateSeparator.tsx` | コンポーネント |
| `src/components/ChatThread.tsx` | コンポーネント |
| `src/components/ChatBubble.tsx` | コンポーネント |
| `src/components/SourcePill.tsx` | コンポーネント |
| `src/components/ScopeSelector.tsx` | コンポーネント |
| `src/components/ChatInput.tsx` | コンポーネント |
| `src/components/TypingIndicator.tsx` | コンポーネント |
| `src/components/SuggestionCard.tsx` | コンポーネント |
| `src/components/TaskGroup.tsx` | コンポーネント |
| `src/components/TaskAddSheet.tsx` | コンポーネント |
| `src/components/SettingsToggle.tsx` | コンポーネント |
| `src/components/SettingsDestructive.tsx` | コンポーネント |
| `src/components/OfflineBanner.tsx` | コンポーネント |
| `src/design/useColors.ts` | フック |
| `src/design/tokens.ts` | トークン（上書き） |

### 改修

| ファイル | 変更内容 |
|---------|---------|
| `src/components/Screen.tsx` | Props拡張、ダークモード対応 |
| `src/components/V6FloatingTabBar.tsx` | FABメニュー整理 |
| `src/components/StateViews.tsx` | CTAボタン追加、イラスト対応 |
| `src/components/StatusPill.tsx` | バリアント追加、日本語化 |
| `src/components/PlayerBar.tsx` | デザインリフレッシュ |
| `src/components/TranscriptionProgressCard.tsx` | 進捗表示改善 |
| `src/features/capture/CaptureFlowProvider.tsx` | フロー簡素化 |
| `src/screens/HomeScreen.tsx` | 全面刷新 |
| `src/screens/FileDetailScreen.tsx` | タブ再設計 |
| `src/screens/AskAIScreen.tsx` | 会話スレッド分離 |
| `src/screens/TasksScreen.tsx` | コンポーネント分離 |
| `src/screens/SettingsScreen.tsx` | グループ再編、開発者情報分離 |

### 削除（参照を外すがファイルは保持）

| ファイル | 理由 |
|---------|------|
| `src/components/V6AudioFileRow.tsx` | `FileCard` に置換 |
| `src/components/AudioFileCard.tsx` | `FileCard` に統合 |

### 変更しないファイル（触れない）

| ファイル | 理由 |
|---------|------|
| `src/native/MemoraNative.ts` | ネイティブブリッジ境界 |
| `src/native/MemoraNative.types.ts` | DTO定義 |
| `src/native/BRIDGE_CONTRACT.md` | 契約ドキュメント |
| `src/features/files/useAudioFiles.ts` | データ取得層（API不変） |
| `src/features/memo/useMemoNotes.ts` | メモデータ層 |
| `src/features/playback/usePlayback.ts` | 再生制御 |
| `src/features/transcription/useTranscriptionTask.ts` | 文字起こし制御 |
| `src/types/memora.ts` | 型定義（追加は可、変更は不可） |
| `src/mocks/memoraData.ts` | モックデータ |
| `modules/memora-native/` | Expo Native Module（変更不可） |
| `app/_layout.tsx` | ルートレイアウト（ルート追加以外変更不可） |
| `app/(tabs)/_layout.tsx` | タブレイアウト |

---

## 次に読むべきドキュメント

- `CODEX_IMPLEMENTATION_PROMPT.md` — 実装指示
