# CODEX_IMPLEMENTATION_PROMPT.md — 実装指示書

> **対象**: Codex / Claude Code 実装エージェント
> **プロジェクト**: Memora `apps/mobile-expo`
> **更新日**: 2026-07-14

---

## 0. 実装前の必須読了ドキュメント

以下の4つの設計ドキュメントを **必ず最初に全文読んでから** 実装を開始すること：

1. `DESIGN.md` — デザイントークン・色・文字・余白・禁止事項
2. `UX_AUDIT.md` — 現状課題・改善優先順位
3. `SCREEN_SPECS.md` — 画面ごとの詳細仕様・状態・日本語文言
4. `COMPONENT_MAP.md` — コンポーネント判断・実装ファイル一覧

読み飛ばした場合、設計意図と異なる実装になるリスクがある。

---

## 1. 変更対象ファイル一覧

### 1.1 トークン・デザイン基盤（最優先）

| ファイル | 操作 |
|---------|------|
| `src/design/tokens.ts` | **全面的に書き換え**（DESIGN.md §2-8 の全トークンに置換） |
| `src/design/useColors.ts` | **新規作成**（ダークモード切替フック） |

### 1.2 新規コンポーネント（全20ファイル）

| ファイル | 説明 |
|---------|------|
| `src/components/SearchBar.tsx` | 常時表示検索バー |
| `src/components/SegmentedControl.tsx` | 汎用セグメントコントロール |
| `src/components/TabBar.tsx` | ファイル詳細タブバー |
| `src/components/FileCard.tsx` | ファイルカード（V6AudioFileRow 代替） |
| `src/components/FileCardSkeleton.tsx` | スケルトンローディング |
| `src/components/DateSeparator.tsx` | 日付区切り |
| `src/components/ChatThread.tsx` | 会話スレッド |
| `src/components/ChatBubble.tsx` | 会話吹き出し |
| `src/components/SourcePill.tsx` | 参照元ピル |
| `src/components/ScopeSelector.tsx` | スコープ切替 |
| `src/components/ChatInput.tsx` | チャット入力 |
| `src/components/TypingIndicator.tsx` | タイピング中表示 |
| `src/components/SuggestionCard.tsx` | 質問提案カード |
| `src/components/TaskGroup.tsx` | タスクグループ |
| `src/components/TaskAddSheet.tsx` | タスク追加シート |
| `src/components/SettingsToggle.tsx` | トグル付き設定行 |
| `src/components/SettingsDestructive.tsx` | 破壊的操作行 |
| `src/components/OfflineBanner.tsx` | オフラインバナー |

### 1.3 改修コンポーネント

| ファイル | 変更内容 |
|---------|---------|
| `src/components/Screen.tsx` | Props 拡張、ダークモード対応、paddingBottom 動的化 |
| `src/components/V6FloatingTabBar.tsx` | FAB メニュー2項目に整理、タブアイコン統一 |
| `src/components/StateViews.tsx` | EmptyState に CTA 追加、全コンポーネントに a11y 設定 |
| `src/components/StatusPill.tsx` | バリアント拡張（5種）+ 日本語ラベル |
| `src/components/PlayerBar.tsx` | デザインリフレッシュ、高さ56px統一 |
| `src/components/TranscriptionProgressCard.tsx` | 進捗バーデザイン刷新、日本語化 |

### 1.4 改修画面

| ファイル | 変更内容 |
|---------|---------|
| `src/screens/HomeScreen.tsx` | セグメントコントロール、FileCard、検索バー常時表示、空状態刷新 |
| `src/screens/FileDetailScreen.tsx` | 4タブ構成、各タブコンテンツ刷新、再生バー常時表示 |
| `src/screens/AskAIScreen.tsx` | 新コンポーネントで再構築、スコープ切替確認、参照元リンク |
| `src/screens/TasksScreen.tsx` | TaskGroup分離、TaskAddSheet差し替え |
| `src/screens/SettingsScreen.tsx` | グループ再編、開発者情報分離、SettingsToggle/SettingsDestructive 使用 |

### 1.5 改修機能

| ファイル | 変更内容 |
|---------|---------|
| `src/features/capture/CaptureFlowProvider.tsx` | 録音フロー1画面化、GenerateOverlay削除 |

---

## 2. 変更しないファイル（絶対に触らない）

これらのファイルは **いかなる理由でも変更しない**：

| ファイル | 理由 |
|---------|------|
| `src/native/MemoraNative.ts` | ネイティブブリッジ境界 — CLAUDE.md §10 保護対象 |
| `src/native/MemoraNative.types.ts` | DTO型定義 |
| `src/features/files/useAudioFiles.ts` | データ取得フック — API不変 |
| `src/features/memo/useMemoNotes.ts` | メモデータ層 |
| `src/features/playback/usePlayback.ts` | 再生制御 |
| `src/features/transcription/useTranscriptionTask.ts` | 文字起こし制御 |
| `src/types/memora.ts` | 型定義 — 追加のみ許可、既存変更禁止 |
| `src/mocks/memoraData.ts` | モックデータ |
| `modules/memora-native/` 以下の全ファイル | Expo Native Module — STTコア保護 |
| `app/_layout.tsx` | ルートレイアウト — 画面追加以外変更不可 |
| `app/(tabs)/_layout.tsx` | タブレイアウト |
| `app/file/[id].tsx` | ルーティングのみ |
| `app/(tabs)/index.tsx` | ルーティングのみ |
| `app/(tabs)/ask-ai.tsx` | ルーティングのみ |
| `app/(tabs)/tasks.tsx` | ルーティングのみ |
| `app/(tabs)/settings.tsx` | ルーティングのみ |
| `package.json` | 依存関係 — 新規追加時は別途協議 |
| `app.json` | Expo設定 |
| `tsconfig.json` | TypeScript設定 |
| `ios/` 以下の全ファイル | iOSネイティブコード |
| `Memora/` 以下の全ファイル | SwiftUI側コード |

---

## 3. 実装順序

### Phase 1: デザイン基盤（最初にやる）

```
Step 1.1: tokens.ts を DESIGN.md §2-8 の新トークンに置換
Step 1.2: useColors.ts を作成（ダークモード切替フック）
Step 1.3: tokens.v6.ts に旧 tokens.ts をバックアップ
```

**確認**: `npm run typecheck` が通ること。画面が壊れても構わない（トークン変更で色が変わるのは想定内）。

### Phase 2: 汎用コンポーネント（画面より先に）

```
Step 2.1: SearchBar.tsx
Step 2.2: SegmentedControl.tsx
Step 2.3: TabBar.tsx
Step 2.4: DateSeparator.tsx
Step 2.5: FileCard.tsx（StatusPill 改修に依存）
Step 2.6: FileCardSkeleton.tsx
Step 2.7: OfflineBanner.tsx
```

**確認**: 各コンポーネントが単体で `typecheck` を通ること。

### Phase 3: Ask AI コンポーネント

```
Step 3.1: SourcePill.tsx
Step 3.2: TypingIndicator.tsx
Step 3.3: ChatBubble.tsx（SourcePill, TypingIndicator に依存）
Step 3.4: ChatInput.tsx
Step 3.5: ScopeSelector.tsx
Step 3.6: SuggestionCard.tsx
Step 3.7: ChatThread.tsx（ChatBubble, TypingIndicator に依存）
```

### Phase 4: タスク・設定コンポーネント

```
Step 4.1: TaskGroup.tsx
Step 4.2: TaskAddSheet.tsx
Step 4.3: SettingsToggle.tsx
Step 4.4: SettingsDestructive.tsx
```

### Phase 5: 既存コンポーネント改修

```
Step 5.1: Screen.tsx
Step 5.2: StateViews.tsx
Step 5.3: StatusPill.tsx
Step 5.4: PlayerBar.tsx
Step 5.5: TranscriptionProgressCard.tsx
```

**確認**: `npm run typecheck`

### Phase 6: 画面実装

```
Step 6.1: HomeScreen.tsx（最優先）
Step 6.2: FileDetailScreen.tsx
Step 6.3: AskAIScreen.tsx
Step 6.4: TasksScreen.tsx
Step 6.5: SettingsScreen.tsx
```

**画面実装時のルール**:
- 各画面を実装したら `npm run typecheck` で確認
- Web プレビューで目視確認（`npm run web`）
- 次の画面に進む前に現在の画面の基本動作を確認

### Phase 7: キャプチャフロー改修

```
Step 7.1: CaptureFlowProvider.tsx — 録音フロー1画面化
Step 7.2: V6FloatingTabBar.tsx — FABメニュー整理
```

**確認**: 録音開始→停止→保存のフローが Web モックで動作すること。

### Phase 8: 最終確認

```
Step 8.1: npm run typecheck（全ファイル）
Step 8.2: npm run web -- --port 8088（Web プレビュー全画面確認）
Step 8.3: 全画面の空状態・エラー状態・ローディング状態を目視確認
Step 8.4: ダークモード切替の動作確認（useColorScheme）
```

---

## 4. 画面ごとの完了条件

### ホーム画面
- [ ] セグメントコントロール「すべて」「お気に入り」「プロジェクト」が動作する
- [ ] 検索バーが常時表示され、入力でリアルタイムフィルタリングされる
- [ ] FileCard がファイル情報（タイトル・日時・長さ・ステータス・要約先頭行）を正しく表示する
- [ ] ファイル0件時に初回空状態（イラスト + CTA）が表示される
- [ ] 検索結果0件時に検索空状態が表示される
- [ ] 読み込み中に FileCardSkeleton が表示される
- [ ] プルダウン更新が動作する
- [ ] 「⋯」メニューから名前変更・削除が実行できる（ブリッジ対応ファイルのみ）
- [ ] オフライン時に OfflineBanner が表示される
- [ ] 全テキストが SCREEN_SPECS.md の日本語文言と一致する

### 録音画面
- [ ] FAB タップ→「録音」で録音モーダルが開く
- [ ] 録音中に経過時間・波形・クイックメモ・タイトル入力が表示される
- [ ] 停止ボタンで録音が停止し、自動保存される
- [ ] 保存完了後にチェックマーク + 「保存しました」が表示される
- [ ] 破棄→確認→録音データ破棄が動作する
- [ ] マイク権限未許可時に権限リクエスト画面が表示される
- [ ] Dynamic Island Pill に録音中/処理中の状態が正しく表示される

### ファイル詳細画面
- [ ] 4タブ（概要・文字起こし・メモ・質問）が切替可能
- [ ] 概要タブ：要約・決定事項・次のアクション・参照が表示される
- [ ] 文字起こしタブ：話者色分け・再生位置ハイライトが機能する
- [ ] メモタブ：テキスト編集・写真添付が可能
- [ ] 質問タブ：Ask AI にスコープ「ファイル」で遷移する
- [ ] 再生バーが常時表示され、再生・一時停止・シーク・速度変更が動作する
- [ ] 文字起こし開始・要約生成がボタンから実行できる
- [ ] 名前変更・削除が正しく動作する
- [ ] 空状態・エラー状態が SCREEN_SPECS.md の仕様通り表示される

### Ask AI 画面
- [ ] ScopeSelector で「全体」「プロジェクト」「ファイル」が切替可能
- [ ] スコープ切替時に確認ダイアログが表示される
- [ ] 会話スレッドが正しく表示される（ユーザー発言とAI回答）
- [ ] SourcePill がタップ可能で該当ファイル詳細に遷移する
- [ ] 回答生成中に TypingIndicator が表示される
- [ ] 空状態で SuggestionCard が表示される
- [ ] ChatInput から質問が送信できる
- [ ] 「コピー」「タスク化」アクションが表示される
- [ ] 「新しい会話」で会話がクリアされる

### タスク画面
- [ ] 「期限切れ」「今日」「今後」「完了」のグループ分けが正しい
- [ ] チェックボックスで完了切替が動作する（アニメーション付き）
- [ ] 元ファイル名タップでファイル詳細に遷移する
- [ ] TaskAddSheet でタスク追加ができる（内容・期限入力付き）
- [ ] 空状態が正しく表示される

### 設定画面
- [ ] 「アカウント」「処理」「通知」「データ」「情報」「アカウント操作」の6グループが表示される
- [ ] SettingsToggle が正しく動作する
- [ ] 開発者向け情報が通常時非表示である
- [ ] 破壊的操作が赤字で表示される
- [ ] 読み込み中にスケルトンが表示される

---

## 5. 受け入れ条件

### 5.1 必須（P0 — すべて満たさなければならない）

- [ ] `npm run typecheck` がエラー0で完了する
- [ ] `npm run web` で全画面がクラッシュせず表示される
- [ ] 全画面の日本語文言が SCREEN_SPECS.md の指定と一致している
- [ ] ネイティブブリッジの API 呼び出しが変更されていない（変更しないファイル一覧のファイルに差分がない）
- [ ] すべてのインタラクティブ要素が 44×44px 以上のタップ領域を持つ
- [ ] 全コンポーネントに `accessibilityLabel` と `accessibilityRole` が設定されている
- [ ] 背景色が `#FAFAF8`（ライト）/ `#0F1114`（ダーク）であり、#FFFAF0 系の warm beige ではない

### 5.2 推奨（P1）

- [ ] ダークモード切替で全画面の色が `darkColors` に切り替わる
- [ ] 空状態・エラー状態・ローディング状態が各画面で確認できる
- [ ] 録音→停止→保存→ホーム表示のフローが Web モックで完結する
- [ ] ファイル詳細のタブ切替がフェードアニメーション（200ms）する
- [ ] タスクのチェック切り替えに完了アニメーションがある

### 5.3 発展（P2）

- [ ] 長い日本語テキスト（議事録など）が `lineHeight: 1.7` 以上で読みやすく表示される
- [ ] Ask AI の質問例が固定ではなく、文脈に応じて変化する（するように見える）
- [ ] スケルトンローディングにシマーアニメーションがある

---

## 6. 検証コマンド

```bash
# 型チェック
cd /Volumes/HIKSEMI/Dev/DesktopProjects/Memora/apps/mobile-expo
npm run typecheck

# Web プレビュー起動
npm run web -- --port 8088

# iOS ビルド検証（シミュレーターが利用可能な場合のみ）
npm run qa:ios:build
```

---

## 7. 実装上の注意

### 7.1 スタイル定義

- `StyleSheet.create()` を使用し、コンポーネント名をプレフィックスにした命名にする
- 例: `const fileCardStyles = StyleSheet.create({ ... })`
- 絶対に `const styles = StyleSheet.create(...)` という汎用名を使わない（複数ファイルで衝突する）

### 7.2 カラー参照

- `colors` を直接インポートせず、`useColors()` フックを使用する
- コンポーネントのトップレベルでは `useColors()` を呼び出し、その戻り値を使う
- トークンは `tokens.ts` からインポートする

```tsx
import { useColors } from '../design/useColors';
import { spacing, radius, typography } from '../design/tokens';

function MyComponent() {
  const colors = useColors();
  // ...
}
```

### 7.3 日本語フォント

- `NotoSansJP_400Regular` / `NotoSansJP_500Medium` / `NotoSansJP_700Bold` を本文用に
- `MPLUS1p_400Regular` / `MPLUS1p_700Bold` を見出し用に
- フォントのロードは既存の `useFonts` などに任せ、コンポーネントでは `fontFamily` を指定するだけ

### 7.4 ネイティブブリッジ

- `MemoraNative` の API 呼び出しは既存のフック経由で行い、直接呼ばない
- データ取得は `useAudioFiles()` / `useAudioFile()` を使う
- 録音は `useCaptureFlow()` を使う
- 文字起こしは `useTranscriptionTask()` を使う
- 再生は `usePlayback()` を使う

### 7.5 アクセシビリティ

- すべての `Pressable` に `accessibilityLabel` と `accessibilityRole` を設定
- トグル・チェックボックスには `accessibilityState` を設定
- 重要な状態変化には `accessibilityLiveRegion` を検討

---

## 8. 実装が完了したら

1. `npm run typecheck` を実行し、エラーがないことを確認する
2. 各画面のスクリーンショットを取得し、SCREEN_SPECS.md のレイアウト図と比較する
3. DESIGN.md §10「禁止事項」に違反していないか目視チェックする
4. 以下の順で全画面の動作を確認する:
   - ホーム → 録音 → 保存 → ファイル詳細 → 文字起こし → Ask AI → タスク → 設定
5. 完了報告を以下のテンプレートで行う:

```
## 実装完了報告

### 変更ファイル一覧
- （作成・変更したすべてのファイルを列挙）

### 確認結果
- typecheck: pass / fail（エラーがある場合は詳細）
- Web プレビュー: 確認済 / 未確認
- 画面数: N画面中N画面実装完了

### 未実装・制限事項
- （あれば列挙）

### スクリーンショット
- （各画面のキャプチャ）
```
