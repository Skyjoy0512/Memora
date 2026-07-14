# RN/Expo UI Polish 実装指示書（Codex向けハンドオフ）

Last updated: 2026-07-13
発行元: Claude Code UIレビューセッション（read-onlyレビュー済み、コード未変更）

## 0. これは何か

`apps/mobile-expo` のUIレビューで確定した修正項目を、**3つの独立したPRバッチ**として実装するための指示書。
各バッチは触るレイヤーが異なるため並行作業可能だが、1バッチ = 1PR を厳守すること。

実装前に必ず読むこと:

- `apps/mobile-expo/AGENTS.md`
- `docs/react-native-expo-migration-plan.md`（Progress / Handoff Log の更新義務あり）
- `docs/Memora_Product_North_Star.md`
- ルートの `CLAUDE.md`（§9 禁止事項 / §10 文字起こしコア保護）

## 1. 絶対に守る境界（全バッチ共通）

- **STTコア禁止**: `Memora/Core/Services/STTService.swift` ほか CLAUDE.md §10 のファイルは読み取りも変更も不要。触らない。
- **SwiftUI側 (`Memora/Views/**`) は変更しない**。このハンドオフは `apps/mobile-expo/**` のみが対象。
- **ネイティブブリッジ (`modules/memora-native/**`, `src/native/**`) のAPI変更は行わない**。UIレーンに限定する。
- 依頼範囲外のついでリファクタ禁止。最小差分。
- 回答・進捗報告・コミットメッセージ本文の説明は日本語。
- ブランチ命名: `fix/rn-ui-<batch>-<slug>`（例: `fix/rn-ui-a-copy-sweep`）。

## 2. 検証方法（全バッチ共通）

```bash
cd apps/mobile-expo
npx tsc --noEmit          # 型チェック必須
npx expo start            # Expo Go で目視確認（可能な環境の場合）
```

- シミュレータが使えない環境では `tsc --noEmit` 成功 + 変更点の自己レビューを完了条件とし、
  完了報告に「目視未実施」と明記する。
- 完了報告テンプレは CLAUDE.md §8 に従う。

---

## バッチA: コピー&偽装の全廃（最優先 / P0）

**目的**: 開発用語の露出・偽データ・偽UIを全て排除する。レイアウトは変更しない。文字列とデータ整合のみ。

### A-1. ユーザー向け文言の集約と内部用語の排除

新規ファイル `apps/mobile-expo/src/design/strings.ts` を作り、ユーザー向け文言定数を集約する。
以下の文言を全て置換する。「bridge / native / mock / facade / SwiftUI / レコード / event stream」という語をUI文字列から全廃する。

| ファイル | 現在の文言 | 置換後 |
|---|---|---|
| `src/components/StateViews.tsx:12` | `Native bridge へ差し替えても同じ状態表示を使います。` | LoadingState の body 自体を削除（ラベルのみ表示。bodyはオプショナルpropにする） |
| `src/components/TranscriptionProgressCard.tsx:36` | タイトル `Native bridge event preview` | `文字起こし` |
| `src/components/TranscriptionProgressCard.tsx:38` | `Swift STT event stream に差し替える前の mock 進捗です。` | 実行中: `音声を解析しています…` / 待機中: `開始すると全文とセグメントが生成されます。`（`isRunning`で分岐） |
| `src/screens/FileDetailScreen.tsx:226` | subtitle `Native bridge facade から読み込みます。` | subtitle を渡さない（削除） |
| `src/screens/FileDetailScreen.tsx:234` | subtitle `Native bridge facade でエラーが発生しました。` | subtitle を渡さない（削除） |
| `src/screens/FileDetailScreen.tsx:124` | `このファイルはまだリネーム対象ではありません。` | `このファイルは現在タイトルを変更できません。` |
| `src/screens/FileDetailScreen.tsx:188` | `このファイルはまだタイトル変更の対象ではありません。` | 同上 |
| `src/screens/FileDetailScreen.tsx:221` | `このファイルはまだ削除対象ではありません。` | `このファイルは現在削除できません。` |
| `src/screens/HomeScreen.tsx:55` | `削除できる native-file レコードが見つかりませんでした。` | `削除できませんでした。もう一度お試しください。` |
| `src/screens/SettingsScreen.tsx:12-13` | `NOT_CONNECTED_MESSAGE`（ネイティブブリッジが…SwiftUI版の…） | A-4 で行ごと disabled 化するため、この Alert 自体を廃止 |
| `src/features/capture/CaptureFlowProvider.tsx:64` (V6FloatingTabBar.tsx:64) | `ネイティブ録音ブリッジの状態を確認してください。` | `録音を開始できませんでした。マイクの許可を確認してください。` |
| `src/components/V6FloatingTabBar.tsx:83` | `ファイル選択またはネイティブブリッジの状態を確認してください。` | `ファイルを取り込めませんでした。もう一度お試しください。` |

英語のaccessibilityLabelも日本語化する:
- `src/screens/AskAIScreen.tsx:114` `Ask AI question` → `質問を入力`
- `src/screens/AskAIScreen.tsx:128` `Ask AI send` → `送信`

### A-2. File Detail 要約タブの偽セクション撤去

対象: `src/screens/FileDetailScreen.tsx:276-330`

現状の問題:
- 「決定事項」セクションが `・{file.summary}`（要約文の流用）
- 「次のアクション」セクションが `file.memo`（メモ配列の流用）
- メタ行の「タスク{file.memo.length}件」が偽
- 下部「要約」セクションと合わせて同一テキストが2回表示される

変更内容:
1. 「決定事項」セクションを**削除**（DTOに `decisions` が存在しないため）。
2. 「次のアクション」セクションを**削除**（`file.memo` はメモでありアクションではない）。
3. メタ行 `{file.duration} ・ 話者N名 ・ タスクN件` から「タスクN件」を外し、`{duration} ・ 話者N名` にする。
4. 「要約」セクションは現在の位置のまま残す（summaryMetadata表示・再生成ボタン含む）。
5. チャプター（transcript先頭4件から導出）と「添付」セクションは実データなので残す。

### A-3. タブバー固定バッジの撤去

対象: `src/components/V6FloatingTabBar.tsx:128`

`const badgeCount = item.routeName === 'tasks' ? 1 : 0;` を `const badgeCount = 0;` 相当に変更し、
バッジ描画コードは残す（将来の実配線用にpropで受けられる形にしてもよいが、既定は非表示）。

### A-4. 「利用できません」Alert の統一（インライン準備中方式へ）

`src/screens/HomeScreen.tsx:154` の FileMoreSheet「プロジェクトに移動」行が正解パターン:
`<View accessibilityState={{ disabled: true }}>` + 行内に「準備中」テキスト + 押しても何も起きない。

このパターンに以下を揃える:

1. **AskAIScreen.tsx:124**（添付ボタン）: Alert をやめ、ボタンを非表示にする（添付機能が来るまで出さない）。
2. **AskAIScreen.tsx:186**（コピー）: `expo-clipboard` は依存に無い場合追加せず、`react-native` の Clipboard は deprecated のため、**コピーボタンごと一旦非表示**にする。依存追加が許される場合のみ `expo-clipboard` を追加して実装（`Clipboard.setStringAsync(message.text)` + 完了時にラベルを1.5秒「コピーしました」に変える）。どちらにしたかを完了報告に書く。
3. **AskAIScreen.tsx:186**（タスク化）: ボタンを disabled 表示（opacity 0.4）+「準備中」suffix、onPressは何もしない。
4. **FileDetailScreen.tsx:281**（タスク化ボタン）: 同上の disabled 表示。
5. **SettingsScreen.tsx**: `notConnected` Alert を廃止。準備中の行（アカウント/デバイス/ストレージ/連携/言語/AIモデル/要約テンプレート/データを削除/ログアウト）は
   - chevron を非表示 (`showChevron={false}`)
   - タイトル色はそのまま、行の右端に `準備中` (fontSize 12, colors.textSubtle)
   - `onPress` は no-op、`accessibilityState={{ disabled: true }}`
   - `SettingsRow` に `disabled?: boolean` prop を追加して実現する。
   - 「プラン」行（auth遷移）と「プッシュ通知」トグルと開発者向けは現状の挙動を維持。
6. **FileDetailScreen.tsx:207-210**（Notion/ChatGPT書き出し）: Alertをやめ、行を disabled 表示+「準備中」。「Markdown / TXT / SRT で書き出す」（実装済みShare）は現状維持。

### A-5. Ask AI のデモ会話・偽タイムスタンプの排除

対象: `src/screens/AskAIScreen.tsx:18-32, 186`

1. `initialMessagesByScope` を全スコープ空配列にする（`askMessages` の import を外す。`src/mocks/memoraData.ts` の `askMessages` は他から未参照になるなら export ごと削除）。
2. メッセージ型 `AskMessage` に `createdAt?: string`（ISO文字列）を追加し（`src/types/memora.ts`）、送信/受信時に `new Date().toISOString()` を設定。表示は `HH:mm` 整形。`createdAt` が無いメッセージは時刻を表示しない。「たった今」固定文字列を廃止。
3. スコープタブ: file / project スコープは**対象を選ぶUIが存在しない**ため、タブごと非表示にして global のみ残す。`scopeOptions` を global のみにし、スコープバーは1件のときレンダリングしない（キャプション「すべての記録を横断して回答します」は残す）。
   - 将来 File Detail から `scope=file` で開く導線が付く際に復活させる旨のコメントを1行残す。

### A-6. 表示名整形のデータ層一元化

対象: `src/components/V6AudioFileRow.tsx:16-19`, `src/features/files/useAudioFiles.ts`

現状 `V6AudioFileRow` が `title.startsWith('native-recording-')` → 「新しい録音」、
summary の `'Recorded by the native Expo module'` を隠すパッチをUI側で行っており、
**File Detail はこのパッチを通らないため生IDが見える**。

変更内容:
1. `useAudioFiles.ts` のデータ取得箇所（一覧・単体の両方）に正規化関数 `normalizeAudioFile(file)` を追加:
   - `title` が `native-recording-` で始まる場合 → `新しい録音`
   - `summary` に `Recorded by the native Expo module` を含む場合 → `summary` を `undefined` に
2. `V6AudioFileRow.tsx` から `displayTitle` / `displaySummary` のパッチロジックを削除し、propの値をそのまま表示。
3. これにより Home 一覧と File Detail のタイトル表示が一致することを確認する。

### バッチA 完了条件

- [ ] `grep -rn "bridge\|mock\|facade\|native-file\|SwiftUI" apps/mobile-expo/src --include="*.tsx" --include="*.ts"` でユーザー向け文字列にヒットしない（変数名・コメント・型名は除外してよい）
- [ ] タスクタブに赤バッジが出ない
- [ ] Ask AI 起動時にデモ会話が出ない・スコープはglobalのみ
- [ ] File Detail 要約タブに「決定事項」「次のアクション」が出ず、summaryは1回だけ表示
- [ ] 設定画面のどの行を押しても Alert が出ない
- [ ] `npx tsc --noEmit` パス

---

## バッチB: インタラクション品質（P1）

**目的**: リスト性能・自動スクロール・ハプティクス・タップ領域・押下表現の統一。
`src/components/**` 中心 + 各画面のハンドラ。バッチAと同一ファイルを触る場合があるため、**バッチAのマージ後にrebaseして着手**するのが安全。

### B-1. Ask AI の自動スクロール

対象: `src/screens/AskAIScreen.tsx`

現状、送信・回答追加時にスクロールが追従せず回答が画面外に出る。

- `Screen` コンポーネントは ScrollView を内包しているが ref を公開していない。`Screen` に `scrollRef?: RefObject<ScrollView>` prop を追加して内部 ScrollView に渡す。
- AskAIScreen で messages / isAnswering の変化時に `scrollRef.current?.scrollToEnd({ animated: true })` を呼ぶ（`useEffect`）。

### B-2. Home 一覧の FlatList 化

対象: `src/screens/HomeScreen.tsx`, `src/components/Screen.tsx`

- `Screen` に `variant?: 'scroll' | 'list'` 相当は**作らない**（改修が大きい）。代わりに Home のファイル一覧は現状の map のままでよいが、`groupedFiles()` が render 中に毎回呼ばれ再計算されるため `useMemo`（依存: `files`, `searchQuery`）に変更する。
- 文字起こしタブ（`FileDetailScreen.tsx:358`）のセグメント一覧も同様に、100件超で重くなる。`file.transcript` を直接 map しているのは維持しつつ、`isSegmentActive` の呼び出しが全行×再生位置更新ごとに走るため、アクティブindexを親で1回計算して行にbooleanで渡す形へ変更する。
- 本格的な FlatList 化は将来の実データ接続後のバッチとし、今回はやらない（このスコープ判断をHandoff Logに記載）。

### B-3. セグメントハイライトの正確化

対象: `src/screens/FileDetailScreen.tsx:499-503`

`isSegmentActive` の「開始+25秒固定」をやめ、**次セグメントの開始時刻を上限**にする:

```ts
function activeSegmentIndex(transcript: TranscriptSegment[], position?: number): number {
  if (position === undefined) return -1;
  for (let i = transcript.length - 1; i >= 0; i--) {
    if (position >= timeToSeconds(transcript[i].time)) return i;
  }
  return -1;
}
```

最終セグメントは曲末まで active。B-2 のアクティブindex一括計算と同時に実装する。

### B-4. ハプティクス導入

`expo-haptics` は既に ios/Pods に含まれている（ExpoHaptics.podspec 確認済み）。`package.json` に含まれているか確認し、無ければ `npx expo install expo-haptics`。

| 操作 | 箇所 | Haptics |
|---|---|---|
| 録音開始 | `CaptureFlowProvider.tsx` `openRecording` 成功時 | `impactAsync(ImpactFeedbackStyle.Medium)` |
| 録音停止 | 同 `stopRecording` 成功時 | `impactAsync(Medium)` |
| 一時停止/再開 | 同 `pauseRecording`/`resumeRecording` | `impactAsync(Light)` |
| タスク完了トグル | `TasksScreen.tsx` `toggleTask` | `notificationAsync(NotificationFeedbackType.Success)`（完了時のみ。解除はLight impact） |
| 削除確定 | `HomeScreen.tsx` `handleDeleteFile` / `FileDetailScreen.tsx` `handleDelete` | `notificationAsync(Warning)` |
| ハイライト追加 | `CaptureFlowProvider.tsx` onHighlight | `impactAsync(Light)` |

Web ビルド（`MemoraNativeModule.web.ts` が存在する）を壊さないよう、`Platform.OS !== 'web'` ガードか動的importで安全にする。

### B-5. 押下(pressed)表現の3種規格化

新規 `src/design/pressable.ts` に共通スタイルを定義:

```ts
export const pressed = {
  row: { backgroundColor: colors.soft },          // リスト行・シート行
  icon: { opacity: 0.5 },                          // アイコンボタン
  button: { opacity: 0.85, transform: [{ scale: 0.97 }] }, // 主ボタン・FAB・録音停止
} as const;
```

置換対象（現状 `scale: 0.93〜0.985` + opacity が混在）:
- `HomeScreen.tsx`: `iconPressed`(0.93) → icon / `sheetRowPressed` → row / `cardPressed` → button(カードは0.97可)
- `AskAIScreen.tsx`: `iconPressed`(0.45) → icon / `suggestionPressed` → row
- `V6FloatingTabBar.tsx`: `pressed`(0.93) → タブは icon、FABは button
- `FileDetailScreen.tsx`: `scalePress` → button
- `TasksScreen.tsx`, `StateViews.tsx`, `PlayerBar.tsx`(0.93), `CaptureFlowProvider.tsx`(0.93) 同様

### B-6. 44pt タップ領域の一括是正

| 箇所 | 現状 | 修正 |
|---|---|---|
| `AskAIScreen.tsx:286` 添付ボタン | 28×32 | バッチAで非表示化済みのため対象外（残す場合は44×44） |
| `PlayerBar.tsx` rateButton | 縦約26pt | `hitSlop={{ top: 10, bottom: 10, left: 8, right: 8 }}` |
| `PlayerBar.tsx` trackWrap | height 12 | `hitSlop={{ top: 14, bottom: 14 }}` |
| `FileDetailScreen.tsx` taskifyButton | minHeight 36 | minHeight 44（バッチAでdisabled化しても領域は確保） |
| `TasksScreen.tsx` sourceLink | hitSlop 4 | hitSlop 10 + minHeight 32（行全体で44確保されているため過剰にしない） |
| `TasksScreen.tsx` doneButton（完了展開） | テキスト+chevronのみ | minHeight 44 |
| `HomeScreen.tsx` connectionRow / header アイコン | ほぼ44未満 | `hitSlop` 追加 |
| `FileDetailScreen.tsx` chapterRow | paddingVertical 8(sm) | minHeight 44 |

### バッチB 完了条件

- [ ] Ask AI で送信すると回答末尾まで自動スクロール
- [ ] 文字起こしタブで再生中セグメントのハイライトが隣接セグメントと重複/欠落しない
- [ ] 録音開始/停止・タスク完了・削除で触感がある（実機。シミュレータ不可なら未検証と報告）
- [ ] pressed 表現が3種類に収まっている（`grep -rn "scale: 0.9" apps/mobile-expo/src` が pressable.ts 以外にヒットしない）
- [ ] `npx tsc --noEmit` パス

---

## バッチC: トークン敷き直し（P1後半+P2）

**目的**: `design/tokens.ts` を実際に使われる状態にし、直値散布と死にスタイルを排除。
**stylesブロックと design/ のみ変更。JSXロジックは変更しない。** バッチA/Bと並走可能（コンフリクト時はstyles行のみ）。

### C-1. typography トークンの実使用化

対象: `src/design/tokens.ts` + 全画面 styles

1. `tokens.ts` の `typography` を実用プリセットに拡張:

```ts
export const type = {
  display: { fontSize: 32, fontWeight: '700' as const, letterSpacing: -0.64, lineHeight: 38 }, // Home大見出し
  title:   { fontSize: 30, fontWeight: '700' as const, letterSpacing: -0.6, lineHeight: 36 },  // 画面タイトル
  heading: { fontSize: 24, fontWeight: '700' as const, letterSpacing: -0.24, lineHeight: 30 }, // File Detailタイトル
  section: { fontSize: 15, fontWeight: '700' as const, lineHeight: 22 },   // セクション見出し
  body:    { fontSize: 15, fontWeight: '400' as const, lineHeight: 24 },   // 本文
  bodySm:  { fontSize: 13, fontWeight: '400' as const, lineHeight: 20 },   // 補助本文
  caption: { fontSize: 12, fontWeight: '400' as const, lineHeight: 17 },   // メタ・キャプション
  label:   { fontSize: 12, fontWeight: '600' as const, lineHeight: 16 },   // グループラベル・バッジ
} as const;
```

2. 全画面の `fontSize` 直値をこの8段に寄せる。**0.5刻みサイズ（10.5/11.5/12.5/13.5/14.5）を全廃**し、最も近い段に丸める。
   例: 12.5→caption(12) or bodySm(13)は文脈で判断、14.5→15(body)、11.5→12。
3. 既存の `typography` export は削除してよい（未使用確認済み）。

### C-2. 直値色のトークン収容

`tokens.ts` に追加し、散布箇所を置換:

| 直値 | 出現箇所 | 対応 |
|---|---|---|
| `#DCE1DE` | AskAIScreen placeholder | **バグ**: `colors.quiet` に置換（トークン追加不要） |
| `colors.border` を placeholder に使用 | FileDetailScreen memoInput / memoPlaceholderText | `colors.quiet` に置換（視認性） |
| `#FAFAFA` | FileDetail memoDisplayBlock | `colors.faint` (#F7F7F7) に寄せる |
| `#D1D1D6` | FloatingBottomSheet handleIndicator | `colors.handle: '#D1D1D6'` 追加 |
| `#D6D6DB` | CaptureFlow 波形pause色 | `colors.waveIdle: '#D6D6DB'` 追加 |
| `#D9D9D9` | generateHandle | `colors.handle` に統一 |
| `#EEEEEE` | PlayerBar track | `colors.paleLine` (#F2F2F2) に寄せる |
| `#F0F0F0` | HomeScreen projectCard border | `colors.cardBorder: '#F0F0F0'` 追加 |
| `#10A37F` / `#000000` | FileDetail exportIcon | C-4 参照 |
| `rgba(255,255,255,0.86)` | シート行背景（3ファイル） | `colors.sheetRow: 'rgba(255,255,255,0.86)'` 追加 |

送信ボタン disabled（AskAIScreen `sendButtonDisabled`）は `backgroundColor: colors.neutralBorder, opacity: 1` に変更（視認性）。

### C-3. ConfirmDialog 共通化

新規 `src/components/ConfirmDialog.tsx`:

```
props: visible, title, body, confirmLabel, confirmDestructive?, cancelLabel?='キャンセル',
       isBusy?, onConfirm, onCancel
```

見た目は現行 FileDetailScreen の LiquidGlassView 版（`colorScheme="light" effect="regular" tintColor="rgba(255,255,255,0.82)"` + `!isLiquidGlassSupported` フォールバック白カード）を正とする。

置換対象（3実装 → 1コンポーネント）:
1. `HomeScreen.tsx` `DeleteConfirm`（素の白カードModal）
2. `FileDetailScreen.tsx:447-449` 削除確認Modal
3. `CaptureFlowProvider.tsx:266-277` 録音破棄確認（absolute View実装 — Modalベースに変わることでレイヤ挙動が正常化する）

リネームModal（TextInput入り）は対象外（現状維持）。

### C-4. 書き出しシートのサービスアイコン

対象: `FileDetailScreen.tsx:454-464`

色付き四角（#000000 / #10A37F / #8E8EA0）をやめ、Ionicons に置換:
- Notion → `document-text-outline`（黒）
- ChatGPT → `chatbubbles-outline`（黒）
- Markdown/TXT/SRT → `download-outline`（黒）
アイコンは `size={20}`, `color={colors.ink}`、`exportIcon` の背景Viewは `colors.faint` の丸角コンテナに変更。
（正規ブランドSVGの導入は別Issue。偽ロゴ色の四角のほうが有害なので汎用アイコンに落とす。）

### C-5. 見出し・呼称の統一

1. `Section.tsx:37` の `textTransform: 'uppercase'` を削除し、`type.label` 相当（12/600, colors.textSubtle）に統一。File Detail の `summarySectionTitle`（15/700）はセクション見出しなので `type.section` へ。
2. Ask タブの呼称統一: `AskAIScreen.tsx:140` の `title="聞く"` → `title="Ask"`（タブバー表記に合わせる）。
3. `SettingsScreen.tsx` 開発者向けセクション全体（117-259行）を `__DEV__ ? (...) : null` でガード。

### C-6. 死にスタイル・死にコンポーネントの削除

1. `FileDetailScreen.tsx` styles から未参照のものを削除:
   `backButton, fileMetaRow, sourceMeta, summaryIntro, heroTop, date, titleBlock, titleRow, heroTitle, renameForm, titleInput, renameActions, iconButton, ghostIconButton, heroSummary, heroActions, actionButton, actionText, ghostButton, ghostText, todoList, todoItem, todoText, sheetBackdrop, sheetPress`
   （削除前に `grep -n "styles\.<name>" FileDetailScreen.tsx` で各々未参照を確認すること）
2. `src/components/AudioFileCard.tsx` / `src/components/StatusPill.tsx`: `grep -rn "AudioFileCard\|StatusPill" apps/mobile-expo/{app,src}` で参照ゼロを確認できた場合のみファイル削除。参照があれば残して報告。

### C-7. ライトモード固定の明示

`apps/mobile-expo/app.json` に `"userInterfaceStyle": "light"`（expo キー直下）が無ければ追加。
colors がライト固定・StatusBar dark固定・LiquidGlass light固定のため、ダーク端末でのシステムUI混在を防ぐ。

### バッチC 完了条件

- [ ] `grep -rn "fontSize: 1[0-4]\.5" apps/mobile-expo/src` がゼロ
- [ ] placeholder が全画面で `colors.quiet`
- [ ] 削除/破棄確認が ConfirmDialog 1実装
- [ ] Section 見出しから uppercase が消えている
- [ ] 開発者向けセクションが production で非表示（`__DEV__` ガード）
- [ ] `npx tsc --noEmit` パス

---

## 実装順序と依存

```
バッチA (P0, 依存なし)  ← 最初に着手・最優先
バッチB (P1)            ← A のマージ後に rebase して着手（同一ファイルの文言変更と衝突するため）
バッチC (P1/P2)         ← A/B と並走可（styles のみ。コンフリクトは styles 行に限定される）
```

## レビュー時に見送った項目（実装しないこと）

- Home 一覧・Transcript の FlatList 化（実データ接続後の性能バッチで対応）
- Ask AI の file/project スコープ復活（対象セレクタUIの設計が先）
- TasksScreen の実データ接続（ブリッジ作業。UIレーン外）
- 生成進捗の実イベント接続（`useTranscriptionTask` との統合はブリッジ側の設計判断が必要）
- 録音波形の実レベル反映（ネイティブブリッジにレベルAPIが無い）
- Notion / ChatGPT の正規ブランドSVG導入

## 完了報告に必ず含めること（CLAUDE.md §8）

- 変更概要 / 変更ファイル一覧 / 影響範囲
- `npx tsc --noEmit` の結果
- Expo Go / シミュレータ目視の有無（不可環境なら「未実施」と明記）
- `docs/react-native-expo-migration-plan.md` の Progress / Handoff Log 更新
