# Open Design v2 刷新 レビュー結果（2026-09-07）

- レビュー担当: Codex 読み取り専用サブエージェント
- 対象: `chore/opencode-20260816`（origin/main より3コミット先行・未push）上の
  未コミット作業ツリー（Open Design v2 刷新、docs/agent-workflows/opendesign-v2-handoff-2026-08-24.md の引き継ぎ分）
- 判定基準: `docs/design/prohibitions.md` / `docs/design/MEMORA_DESIGN.md` §7（タイポグラフィ）・§9（状態）
- 本レビューは読み取りのみ。このファイル以外への書き込み・git 操作は行っていない

---

## 1. 変更概要

作業ツリーの状態（ステージ済み含む）:

- 30 ファイル変更（+2,782 / -2,063、非ステージ）
- 3 ファイル削除ステージ済み: `app/ask.tsx` / `src/components/HomeComposer.tsx` / `src/screens/AskAiOverlayScreen.tsx`
- 未追跡: `src/components/Buttons.tsx`, `ProcessRail.tsx`, `ToggleSwitch.tsx`, `AskEntryBar.tsx`,
  `NumericText.tsx`, `useTabBarClearance.ts`, `src/features/home/HomeViewState.tsx`,
  `src/utils/recordingHabit.ts`(+テスト) ほか、ルート資料群・`Memora-DesignSystem-v07.html`・`docs/design-system/**`

主な内容:

- デザイン正本を v0.6/v0.7（Memora-DesignSystem-v07.html / docs/design-system）へ更新
- トークン刷新: 寒色モノクロ（hue 220）ランプ化、`radius` 全廃（矩形=0、円のみ circle）、
  IBM Plex Sans JP / Inter / Plex Mono の導入、`textStyles.rowTitle` / `label` 追加
- 画面刷新: Home / Tasks / AskAI / Settings / FileDetail / AuthFlow / CaptureSheet /
  CaptureFlowProvider を書き換え、Ask AI は常設コンポーザー廃止＋入口（AskEntryBar）方式へ
- `app/ask.tsx`（fullScreenModal）と AskAiOverlayScreen を廃止し、Ask AI タブへ集約

---

## 2. OK 項目

- **生 HEX なし**: `src/**`（トークンファイル除く）に `#[0-9A-Fa-f]{3,8}` 直書きは 0 件。
  `global.css` の HEX は v0.7 トークンと同値の web 側 CSS 変数マッピング（B5 のパレット整合が実施済み）。
- **アイコン単体ボタンのラベル**: 新規 `Buttons.tsx` は全バリアントで `accessibilityLabel` 必須。
  icon-only Pressable（FileCard more / SearchBar clear / 写真削除・添付 / generateBack / RoundIcon /
  PlayerBar 各ボタン等）はいずれもラベル付き。§8.2 違反なし。
- **ボタンの状態**: PrimaryAction / SecondaryAction / SheetAction / IconButton / AskEntryBar /
  ToggleSwitch に pressed / disabled（＋ `accessibilityState`）を実装。§4.2 / §4.3 OK。
- **カード化の解消**: 一覧行は `surface` + ヘアライン（borderBottom）で表現（FileCard / Tasks / Settings 行）。
  `surfaceElevated` / 影の乱用なし。影は `shadow.floating`（= floatingNav へマップ）のみ使用。
- **角丸**: 新規コンポーネントは `radius: 0`（矩形）で、円のみ `radius.circle`。
- **状態の色だけ表現なし**: ProcessRail（罫線＋文言＋ n/3）、StatusPill、ToggleSwitch（checked trait）、
  Task checkbox（図形＋ラベル＋accessibilityState）等、非色の手掛かり併設。
- **進捗の実測**: heroui-native の ProgressBar 不使用。ProcessRail は実状態から step を導出しラベル付き。
  TranscriptionProgressCard / CaptureFlow の % 表示は実測 `progress` を幅へ反映（偽装なし）。§7.4 OK。
- **メタデータ階層**: 日時・長さ等は `footnote` / `mono` + tabular-nums（NumericText）で小さく。
- **削除モジュールの参照残りなし**: `HomeComposer` / `AskAiOverlayScreen` / `/ask` への import・
  router 参照は 0 件（`rg` で確認）。Ask AI は `/ask-ai` タブへ一本化。
- **Safe Area / タブ被り**: 57 / 60 / 76 / 112 のバラバラ値を `useTabBarClearance` へ一元化。
- **録音まわり**: recording 色は赤系（danger と同系）のみで、波＋タイマー＋ラベル併設。

---

## 3. 要修正リスト（ファイル:行・具体策）

### 3-1. AskAIScreen の対象スコープ行が 44pt 未満のまま（§4.1 / §8.1）

- `apps/mobile-expo/src/screens/AskAIScreen.tsx:210-211`（onPress Pressable、`styles.scopeRow`）
- `apps/mobile-expo/src/screens/AskAIScreen.tsx:513-518`（`scopeRow: minHeight: 36`）

内容: 質問対象を切り替える Pressable が `minHeight: 36` かつ hitSlop なし。
縦タップ領域が 36pt 前後で 44pt に届かない。

具体策: `scopeRow` へ `minHeight: 44` を設定するか、
Pressable に `hitSlop={{ top: 4, bottom: 4 }}` を付与（36 + 8 = 44）。

### 3-2. FileDetailScreen に未使用スタイルの残骸（生 fontSize・40pt ボタン定義）

- `apps/mobile-expo/src/screens/FileDetailScreen.tsx:1188`（`backButton` height 40）
- `apps/mobile-expo/src/screens/FileDetailScreen.tsx:1211-1214`（`date` fontSize 12）
- `apps/mobile-expo/src/screens/FileDetailScreen.tsx:1225-1230`（`heroTitle` fontSize 24）
- `apps/mobile-expo/src/screens/FileDetailScreen.tsx:1236-1243`（`titleInput` fontSize 18）
- `apps/mobile-expo/src/screens/FileDetailScreen.tsx:1256-1264`（`iconButton` / `ghostIconButton` height 40）

内容: 刷新後のレンダリングから参照されないデッドスタイル（`styles.date` / `styles.heroTitle` /
`styles.titleInput` / `styles.backButton` / `styles.iconButton` / `styles.ghostIconButton` は
いずれも使用 0 件）。生 fontSize（12 / 24 / 18）と 40pt タップ定義を未使用のまま保持している。

具体策: 使用箇所を再確認したうえで未使用定義を削除。将来使う場合は
`textStyles`（12 は caption1 相当をアダプタへ公開、24 は title 系トークン追加）へ置換。

### 3-3. PlayerBar フォローアップ（修正1・修正2）が未反映

詳細は §5 参照。`docs/agent-workflows/opencode-followup-2026-08-16.md` の
修正1（trackWrap 縦 hitSlop）・修正2（rateButton 横 hitSlop 拡張）は作業ツリーに未適用。

---

## 4. 判断保留（理由つき）

1. **フォントパッケージ導入と禁止文書の衝突**
   - `apps/mobile-expo/package.json`: `@expo-google-fonts/inter`・`@expo-google-fonts/ibm-plex-mono` を追加
   - `src/theme/tokens.ts` の `fontFamily` / `src/design/tokens.ts` の `fonts` / `app/_layout.tsx` の `useFonts`
   - 理由: prohibitions §3.1・MEMORA_DESIGN §7（2026-08-02 時点）は「フォントパッケージ非依存・System フォント」。
     一方 v0.6/v0.7 正本（Memora-DesignSystem-v07.html・トークンコメント）は Plex/Inter 採用を明記。
     旧禁止文書と新デザイン正本が衝突。**どちらを正とするかの意思決定が必要**（禁止文書側を更新するか、フォント案を撤回するか）。
2. **録音タイマーの fontSize 12 / 44 のトークン化**
   - `src/features/capture/CaptureFlowProvider.tsx:1117`（islandTimer 12）、`:1163`（recordingTime 44）
   - 理由: いずれも前回レビューで「判断保留」とした既存値（12 は theme に caption1 があるがアダプタ未公開、
     44 は typography.size 上限 34 を超える）。刷新でトークン追加に至らなかった。既存持ち越しのため本刷新の新規違反ではない。
3. **非 4pt の微細値（カスタム部品・ブランドマーク内）**
   - `src/components/ToggleSwitch.tsx:47` `paddingHorizontal: 1`（knob の移動量とトラック内の整合を取る 1px）
   - `src/screens/AuthFlowScreen.tsx:578-581` `gap: 5` / `width: 5`（MEMORA ブランドマークの 5pt バー。
     radius 例外はコメントで明記済みだが gap 自体は 4pt 倍数でない）
   - 理由: どちらもレイアウトリズムではなく制御内部のジオメトリ／図形単位。特例として明記するか 4pt 倍数へ寄せるかの判断を保留。
4. **既存持ち越しの非 4pt・raw rgba**
   - `src/screens/FileDetailScreen.tsx:1335` `gap: 2`、`:1176` / `:1545` `rgba(13,13,13,…)`
   - `src/features/capture/CaptureFlowProvider.tsx:1142` `paddingTop: 58`（非 4pt）
   - 理由: すべて HEAD 時点から存在（Attachment バッジ等、画像上のオーバーレイ用途）。
     刷新で新規追加されたものではない。scrim / glassFallback トークンへ寄せる余地あり。
5. **タブラベル・IA 文書の整合**
   - `app/(tabs)/_layout.tsx`: ホームタブを「記録」へ改名、録音ラベルを再表示、Ask AI をタブ集約
   - 理由: IA 文書（navigation.md / information-architecture.md）は「ホーム」表記・
     BottomAccessory 常設 AI コンポーザーを記載。v0.7 正本に合わせた変更とみられるが、
     MEMORA_DESIGN §13「IA は変更しない」との整合を確認する必要がある。
6. **一覧行 Pressable の実効タップ高さは実測推奨**
   - `FileDetailScreen.tsx:586` チャプター行、`TasksScreen.tsx` ソースリンク行などは明示 height なし
   - 理由: 行の実効高さはテキスト lineHeight + padding 依存。44pt 未満になる行がないか実機/実測での確認を推奨。

---

## 5. PlayerBar フォローアップ判定

対象: `apps/mobile-expo/src/components/PlayerBar.tsx`（作業ツリー時点）

### 修正1（trackWrap 縦 hitSlop）: **未反映**

- `PlayerBar.tsx:49` trackWrap Pressable に `hitSlop` なし
- `PlayerBar.tsx:99-101` `trackWrap: { height: 12, justifyContent: "center" }`

→ 高さ 12pt のまま。`hitSlop={{ top: 16, bottom: 16 }}`（12 + 32 = 44）等の追加が必要。

### 修正2（rateButton 横 hitSlop 拡張）: **未反映**

- `PlayerBar.tsx:44` `hitSlop={{ bottom: 10, left: 2, right: 2, top: 10 }}`（変更なし）
- `PlayerBar.tsx:79-85` rateButton は `paddingHorizontal: 8 ×2` + テキスト（mono 11 で "1x" ≈ 13pt）→
  実寸は横 ≈ 29pt。`left/right: 2` では実効 ≈ 33pt で **44pt 未満**

→ `left/right` を各 7〜8pt（29 + 15 ≈ 44）へ拡張。右端は spacer に接し画面端寄りのため干渉は軽微と推定。
  実装時はレイアウトで隣接要素と重ならないことを確認。

### 確認3（7 箇所の実効タップサイズ表）

フォローアップ指示の「前回追加した 7 箇所」を現在の作業ツリーで再計算:

| 箇所 | 実寸(縦×横) | hitSlop | 実効(縦×横) | 44pt 到達 |
|---|---|---|---|---|
| CaptureFlowProvider generateBack | 40×40 | 2 | 44×44 | OK |
| CaptureFlowProvider islandRecording | 36×幅いっぱい | {4,4} | 44×幅いっぱい | OK |
| CaptureFlowProvider islandGeneration | 36×幅いっぱい | {4,4} | 44×幅いっぱい | OK |
| CaptureFlowProvider RoundIcon(small) | 40×40 | 2 | 44×44 | OK |
| AuthFlowScreen back | 40×40 | 2 | 44×44 | OK |
| FileDetailScreen 写真削除 | 20×20 | 12 | 44×44 | OK |
| PlayerBar rateButton | 24×29 | {10,10,2,2} | 44×33 | **横のみ未達** |

→ 7 箇所中 6 箇所は 44pt 到達。rateButton のみ横が未達（＝修正2）であり、
trackWrap（7 箇所に含まれないが要対応）も未対応。フォローアップ指示は**未実行**の状態。

### 判定

**PlayerBar フォローアップ（修正1・修正2）は未反映。**
作業ツリーの PlayerBar 差分は radius / mono / 時刻表記のみで、hitSlop は変更されていない。
本刷新に含めず別コミットで対処するか、刷新と同時に反映するかを要判断。

---

## 6. 最重要の要修正サマリ

1. **PlayerBar の trackWrap・rateButton hitSlop 未適用**（修正1・修正2）— a11y 必須要件
2. **AskAIScreen 対象スコープ行（36pt・hitSlop なし）** — §4.1/§8.1
3. **FileDetailScreen の未使用スタイル残骸**（生 fontSize 12/24/18・40pt 定義）— 後始末

判断保留は §4 の 6 件（うちフォント方針は禁止文書との衝突につき上位判断が必要）。
