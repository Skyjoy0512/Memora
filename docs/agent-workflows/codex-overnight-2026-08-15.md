# Codex 夜間実行プロンプト（2026-08-15）

以下をそのまま Codex に渡してください。

---

あなたは Memora の Lane F（RN UI）実装担当です。無人で夜間作業を行います。

目視確認はできませんが、**このリポジトリには単体テスト基盤があります**
（`npm test` = vitest、現在 8 ファイル / 65 件が pass）。
テストで検証できる作業は積極的に進めてください。

## 0. 環境の制約（先に把握すること。試して時間を溶かさない）

このサンドボックスでは次が**必ず失敗します**。実行しないでください。

- **ネットワークアクセス** — `npm install` / `pod install` / `git fetch` / 外部ドキュメント閲覧は不可
- **Simulator 操作** — `xcodebuild` / `xcrun simctl` は CoreSimulatorService に接続できず失敗
- **`npm run qa:ios:build`** — 同上

Expo や HeroUI の API を確認したいときは、公式サイトではなく
`apps/mobile-expo/node_modules/` 配下の**型定義と実装を直接読んで**ください。

`git commit` が `index.lock: Operation not permitted` で失敗する場合は、
**再試行せず**、差分を作業ツリーに残したまま報告してください。

## 1. 作業ブランチ

```
git checkout -b feat/rn-overnight-20260815 origin/main
```

**次のブランチには絶対に触らないでください**（レビュー中の PR）:
`fix/rn-select-label-reland` / `fix/rn-list-typography` / `fix/rn-capture-safearea-tokens`

`apps/mobile-expo/ios/Podfile.lock` にローカル差分があります。
**触らない・ステージしない。**

## 2. 必ず先に読むもの

- `docs/design/prohibitions.md` — 判定基準
- `docs/design/MEMORA_DESIGN.md` §7（タイポグラフィ）・§9（状態）
- `apps/mobile-expo/src/design/tokens.ts` / `src/theme/tokens.ts`

## 3. タスク

**タスクごとにコミットを分けてください。** 上から順に実施。

---

### T1【実装】生成失敗画面が「何が起きたか」を伝えていない

**実機で確認済みの不具合です。**

録音後に「処理を開始」を押して要約生成が失敗すると、次の画面が出ます:

- 見出し: **「生成に失敗しました」**
- 本文: **「生成に失敗しました。ファイルは保存されています。」**
- 空のプログレスバーが残ったまま
- 「閉じる」だけ

問題は3つあります。

1. **見出しと本文が同じ文の重複**で、本文が情報を足していない
2. **失敗の理由が書かれていない。** 実際の原因は「要約モデルに Gemini が
   選ばれているが API キーが未設定」だが、ユーザーには分からない
3. **復帰する導線が無い。** Ask AI 側には同じ状況で
   「設定で API キーを入力」ボタンがあるのに、ここには無い

該当は `src/features/capture/CaptureFlowProvider.tsx` の生成中/失敗画面。

**やること**:

- 既存の `src/native/askAiLogic.ts` の `mapAskAiError` が返す
  `hint: 'api-key'` の仕組みを読み、**同じ判定を再利用**してください。
  新しいエラー分類を発明しないこと
- API キー未設定に起因する失敗なら、**理由を明示し、設定画面への導線**を出す
  （`AskAiOverlayScreen` の該当箇所と同じ文言・同じ遷移に揃える）
- それ以外の失敗は、**重複を解消した文言**にする
  （見出しは状態、本文は「次に何ができるか」を書く）
- **失敗時に空のプログレスバーを残さない。**
  `prohibitions.md` §7.4「実測値が無いのに `ProgressBar` を使わない」に該当します

**制約**: 文言・導線の変更に留め、画面構成を作り変えないこと。
判断に迷ったら変更せず報告してください。

---

### T2【テスト】ロジックモジュールの単体テストを追加する

`npm test` で完全に検証できる、夜間に最も安全で価値のある作業です。

まずカバレッジの穴を調べてください:

```
ls apps/mobile-expo/src/utils apps/mobile-expo/src/native
ls apps/mobile-expo/src/utils/__tests__
```

**テスト対象の候補**（純粋ロジックで副作用が無いもの）:

- `src/native/askAiLogic.ts` — `buildAskAiRequest` / `mapAskAiError` /
  `isSupportedAskAiModel` / スコープ解決
- `src/native/exportLogic.ts` — Notion / ChatGPT 書き出しの整形・ID 抽出
  （`extractNotionParentPageId` は URL 形式の分岐が多く、テスト価値が高い）
- `src/native/taskLogic.ts`
- `src/utils/` で未テストのもの

**方針**:

- 既存テスト（`src/utils/__tests__/*.test.ts`）の書き方・命名に合わせる
- **正常系だけでなく、境界と異常系を書く**
  （空文字・不正な URL・未知のプロバイダ・null など）
- テストのためにプロダクションコードのシグネチャを変えないこと。
  テストしにくい構造を見つけたら、**変更せず報告**してください
- `npm test` が全件 pass することを確認してからコミット

**既存の 65 件を壊さないこと。**

---

### T3【調査】未実装導線の棚卸し

アプリには「準備中」「この操作は現在利用できません。」で止まる導線が
**12 箇所**あります。

```
grep -rn --include='*.tsx' -E "準備中|現在利用できません" apps/mobile-expo/src apps/mobile-expo/app
```

リリース判断の材料として一覧を作ってください。**コードは変更しないこと。**

`docs/agent-workflows/codex-overnight-2026-08-15-result.md` に表で記載:

| 画面 | 操作 | ファイル:行 | ユーザーへの見え方 | 分類 |
|---|---|---|---|---|

分類は次のいずれか（判断できなければ「要判断」）:

- **未実装**: 機能自体がまだ無い
- **意図的な制限**: Free プランの制限など、仕様として正しい
- **要判断**: どちらか分からない

「準備中」と出るだけで**何も起きない操作が、ユーザーから見て
何箇所あるのか**が分かる形にしてください。

---

### T4【品質】アイコンボタンの読み上げラベル欠落

`prohibitions.md` §8.2「アイコン単体ボタンに `accessibilityLabel` が無い」を禁止。

`isIconOnly` が 13 箇所あり、`accessibilityLabel` が確認できるのは 4 箇所のみです。

```
grep -rn --include='*.tsx' -A6 "isIconOnly" apps/mobile-expo/src apps/mobile-expo/app
```

- `isIconOnly` の Button と、アイコンだけを描画している `Pressable` の**両方**を精査
- 欠落分に、操作内容が伝わる日本語ラベルを付ける。既存ラベルは書き換えない
- **見た目は変わりません。スタイルを触らないこと**

---

### T5【品質】44pt 未満のタップ領域を hitSlop で補う

`prohibitions.md` §4.1 / §8.1。テスト条件に
「**44×44 未満のコンテンツは `hitSlop` で補うこと**」と明記されています。

```
grep -rn --include='*.tsx' -E "(height|minHeight): (2[0-9]|3[0-9]|4[0-3])\b" apps/mobile-expo/src apps/mobile-expo/app
```

15 箇所ヒットしますが**すべてが対象ではありません**。

- **対象**: `onPress` を持つ操作可能な要素
- **対象外**: 表示専用（アバター、プログレスバー、装飾、情報表示ピル等）

**必ず `hitSlop` で補い、要素のサイズは変えないこと。**
サイズを変えるとレイアウトが動き、目視できない夜間作業では検証不能になります。

迷うものは**変更せず「判断保留」として報告**してください。

---

### T6【品質】fontSize 直書きをトークンへ

`prohibitions.md` §3.2。現状 9 箇所:

```
src/features/capture/CaptureFlowProvider.tsx:1050  fontSize: 12
src/features/capture/CaptureFlowProvider.tsx:1096  fontSize: 44
src/screens/AuthFlowScreen.tsx:581                 fontSize: 18
src/screens/AuthFlowScreen.tsx:589                 fontSize: 15
src/screens/FileDetailScreen.tsx:1123              fontSize: 12
src/screens/FileDetailScreen.tsx:1138              fontSize: 24
src/screens/FileDetailScreen.tsx:1152              fontSize: 18
src/screens/FileDetailScreen.tsx:1192              fontSize: 16
app/(tabs)/_layout.tsx:32                          fontSize: 11
```

- `textStyles` / `typography.size` に**同じ値があるならそれを使う**（見た目不変）
- **同じ値が無いもの**（44 / 24 等）は勝手に丸めないこと。見た目が変わります。
  **変更せず報告**し、トークン追加が必要である旨を書く
- `app/(tabs)/_layout.tsx:32` は NativeTabs のラベル設定でネイティブ側に渡ります。
  トークン化できるか慎重に判断し、疑わしければ**変更せず報告**

---

## 4. 共通ルール

- **T1 以外は見た目を変えない。** サイズ・余白・色を変更しない
- 生 HEX 禁止。4pt 基底を守る
- 新規パッケージ追加禁止。`expo prebuild` 禁止
- 変更してよいのは `apps/mobile-expo/src/**` と `apps/mobile-expo/app/**`
  （報告ファイルのみ `docs/agent-workflows/` への書き込みを許可）
- `ios/**`・`modules/**`・`Packages/**`・`.github/**` は変更しない
- **判断に迷ったら変更せず報告。推測で直さないこと**

## 5. 検証（各タスクのコミット前に必ず実行）

```
cd apps/mobile-expo
npm test
npm run typecheck
npx expo export --platform web
```

リポジトリルートで `git diff --check`。

**いずれかが fail したら、そのタスクの変更を戻して次のタスクへ進んでください。**
失敗を抱えたまま先に進まないこと。1つのタスクで詰まっても、
残りのタスクは独立しているので続行できます。

## 6. やってはいけないこと

- `git push`
- PR の作成・編集・マージ
- 上記3ブランチへの操作
- Simulator / ビルド関連コマンドの実行
- T1 以外での見た目の変更

## 7. 報告

`docs/agent-workflows/codex-overnight-2026-08-15-result.md` に書いてください。

含めるもの:

- **タスクごとに**: 実施内容 / 変更ファイル / 検証結果（コマンドと pass・fail）/ コミットハッシュ
- **判断保留にしたものの一覧と理由**（最重要。ここが翌朝の作業の起点になります）
- T2: 追加したテストの件数と、テスト後の合計件数
- T3: 未実装導線の一覧表
- 作業後の再 grep 結果（T4 / T5 / T6 の残件数）
- 着手できなかったタスクと、その理由

最後に `git status --short` と `git log --oneline origin/main..HEAD` を貼ってください。
