# OpenCode 引き継ぎプロンプト（2026-08-16）

以下の `---` から下をそのまま OpenCode に渡してください。

---

# Memora リポジトリでの作業依頼

あなたは Memora プロジェクトの実装担当（役割名: OpenCode）です。
このリポジトリを初めて触る前提で、必要な情報をすべて以下に書きます。

**使用モデルは DeepSeek のみです。** 他モデルへ切り替えないでください。
切り替えが必要だと判断した場合は、作業を止めてその旨を報告してください。

---

## 1. このリポジトリは何か

- **Memora** = iPhone 向けの録音・文字起こし・要約アプリ
- リポジトリのルート: `/Volumes/DevSSD/Development/Projects/Memora`
- アプリ本体は **React Native / Expo** で、`apps/mobile-expo/` にあります
- 以前は SwiftUI 版もありましたが**削除済み**です。今は RN 版が唯一のアプリです

### 主なディレクトリ

| パス | 中身 |
|---|---|
| `apps/mobile-expo/src/` | 画面・コンポーネント・ロジック（**主な作業対象**） |
| `apps/mobile-expo/app/` | 画面のルーティング（Expo Router） |
| `apps/mobile-expo/modules/memora-native/` | iOS ネイティブ連携（Swift）。**今回は触らない** |
| `apps/mobile-expo/ios/` | iOS プロジェクト。**今回は触らない** |
| `Packages/MemoraSharedData/` | Swift の共有ロジック。**今回は触らない** |
| `docs/design/` | デザインの正本（判断基準） |

---

## 2. 最初に読むべきファイル

作業前に必ず読んでください。

1. `CLAUDE.md`（リポジトリ直下）— 開発ルール全般
2. `docs/design/prohibitions.md` — **禁止事項リスト。今回の判断基準そのもの**
3. `docs/design/MEMORA_DESIGN.md` — デザイン方針（特に §7 タイポグラフィ）
4. `apps/mobile-expo/src/design/tokens.ts` と `apps/mobile-expo/src/theme/tokens.ts` — 色・余白・文字サイズの定義

---

## 3. 守るルール

### 変更してよい範囲

- `apps/mobile-expo/src/**`
- `apps/mobile-expo/app/**`
- 報告ファイルのみ `docs/agent-workflows/` への書き込みを許可

### 変更してはいけないもの

- `apps/mobile-expo/ios/**`
- `apps/mobile-expo/modules/**`
- `Packages/**`
- `.github/**`
- `docs/`（上記の報告ファイルを除く）
- `apps/mobile-expo/package.json` / `package-lock.json`（**新規パッケージ追加禁止**）
- `apps/mobile-expo/ios/Podfile.lock`（ローカル差分があります。**触らない・ステージしない**）

### 実行してはいけないコマンド

- `npx expo prebuild` — **手書きの iOS 設定が消えます。絶対に実行しないこと**
- `git push`
- PR の作成・編集・マージ
- `npm install` / `pod install`（依存は変更しません）

---

## 4. 作業ブランチ

```bash
cd /Volumes/DevSSD/Development/Projects/Memora
git fetch origin
git checkout -b chore/opencode-20260816 origin/main
```

**次のブランチには絶対に触らないでください**（レビュー中）:

- `chore/ci-automerge-default`

---

## 5. タスク

**上から順に。1つ終えるごとに検証してコミットしてください。**
1つで詰まっても他は独立しているので、次へ進んで構いません。

---

### タスクA【最重要】ロジックの単体テストを追加する

このリポジトリには **vitest** のテスト基盤があります。
現在 8 ファイル / 65 件が pass します。

```bash
cd apps/mobile-expo
npm test
```

**テストが書かれていないロジックにテストを足してください。**

対象候補（副作用の無い純粋関数で、テストしやすいもの）:

- `apps/mobile-expo/src/native/askAiLogic.ts`
- `apps/mobile-expo/src/native/exportLogic.ts`
  （`extractNotionParentPageId` は URL の形式分岐が多く、特にテスト価値が高い）
- `apps/mobile-expo/src/native/taskLogic.ts`

既存テストの場所と書き方:

```
apps/mobile-expo/src/utils/__tests__/*.test.ts
```

**必ず既存テストを読んで、同じ書き方・同じ命名規則に合わせてください。**

書くべき内容:

- 正常系だけでなく、**境界と異常系**（空文字・不正な URL・未知の値・null / undefined）
- **プロダクションコードのシグネチャは変えないこと。**
  テストしにくい構造を見つけたら、変更せず報告してください

**既存の 65 件を壊さないこと。** `npm test` が全件 pass してからコミットします。

---

### タスクB アイコンだけのボタンに読み上げラベルを付ける

`docs/design/prohibitions.md` §8.2 で
「アイコン単体ボタンに `accessibilityLabel` が無い」ことが禁止されています。

現状 `isIconOnly` が 13 箇所あり、`accessibilityLabel` が付いているのは 4 箇所だけです。

```bash
cd /Volumes/DevSSD/Development/Projects/Memora
grep -rn --include='*.tsx' -A6 "isIconOnly" apps/mobile-expo/src apps/mobile-expo/app
```

やること:

- `isIconOnly` の Button と、アイコンだけを描画している `Pressable` の**両方**を調べる
- ラベルが無いものに、**その操作が何をするか**が伝わる日本語ラベルを付ける
- 既存のラベルは書き換えない

**見た目は一切変わりません。スタイル（色・サイズ・余白）を触らないでください。**

---

### タスクC タップ領域が 44pt 未満のものを hitSlop で補う

`prohibitions.md` §4.1 / §8.1 で、タップ領域は最低 44×44 pt と決まっています。
同じ項目に「**44×44 未満のコンテンツは `hitSlop` で補うこと**」と明記されています。

候補を出すコマンド:

```bash
grep -rn --include='*.tsx' -E "(height|minHeight): (2[0-9]|3[0-9]|4[0-3])\b" apps/mobile-expo/src apps/mobile-expo/app
```

15 箇所ヒットしますが、**すべてが対象ではありません。**

- **対象**: `onPress` を持つ、押せる要素
- **対象外**: 表示するだけの要素（アバター画像、プログレスバー、装飾、
  情報表示用のピルなど）。これらは触らないでください

**必ず `hitSlop` を追加して補ってください。要素の `height` / `width` を変えないこと。**

理由: サイズを変えると画面のレイアウトが動きます。今は実機で見た目を確認できる人が
いないため、レイアウトが動くと検証できなくなります。

判断に迷うものは**変更せず、報告に「判断保留」として理由付きで列挙**してください。

---

### タスクD 文字サイズの直書きをトークンに置き換える

`prohibitions.md` §3.2 で「トークンに無い `fontSize` を直書きする」ことが禁止されています。

現状 9 箇所:

```
apps/mobile-expo/src/features/capture/CaptureFlowProvider.tsx:1050  fontSize: 12
apps/mobile-expo/src/features/capture/CaptureFlowProvider.tsx:1096  fontSize: 44
apps/mobile-expo/src/screens/AuthFlowScreen.tsx:581                 fontSize: 18
apps/mobile-expo/src/screens/AuthFlowScreen.tsx:589                 fontSize: 15
apps/mobile-expo/src/screens/FileDetailScreen.tsx:1123              fontSize: 12
apps/mobile-expo/src/screens/FileDetailScreen.tsx:1138              fontSize: 24
apps/mobile-expo/src/screens/FileDetailScreen.tsx:1152              fontSize: 18
apps/mobile-expo/src/screens/FileDetailScreen.tsx:1192              fontSize: 16
apps/mobile-expo/app/(tabs)/_layout.tsx:32                          fontSize: 11
```

※ 行番号は変わっている可能性があります。grep で再確認してください:

```bash
grep -rn --include='*.tsx' -E "fontSize: [0-9]" apps/mobile-expo/src apps/mobile-expo/app
```

やること:

- `apps/mobile-expo/src/design/tokens.ts` の `textStyles` / `typography.size` を読む
- **同じ値がトークンにあるなら、それを使う**（見た目は変わりません）
- **同じ値が無いもの**（44 や 24 など）は、**近い値に勝手に丸めないでください。**
  見た目が変わります。**変更せず報告**し、「トークン追加が必要」と書いてください
- `app/(tabs)/_layout.tsx:32` はタブバーの設定で、**値がネイティブ側に渡ります。**
  トークン化してよいか慎重に判断し、少しでも疑わしければ**変更せず報告**してください

---

### タスクE【調査のみ】未実装の導線を一覧にする

アプリには「準備中」「この操作は現在利用できません。」と出るだけで
何も起きない操作が **12 箇所**あります。

```bash
grep -rn --include='*.tsx' -E "準備中|現在利用できません" apps/mobile-expo/src apps/mobile-expo/app
```

**コードは一切変更しないでください。** 一覧表を作るだけです。

報告ファイルに次の形式で書いてください:

| 画面 | 操作 | ファイル:行 | ユーザーにどう見えるか | 分類 |
|---|---|---|---|---|

分類は次の3つから選びます。判断できなければ「要判断」にしてください。

- **未実装**: 機能そのものがまだ無い
- **意図的な制限**: 無料プランの制限など、仕様として正しいもの
- **要判断**: どちらか分からない

---

## 6. 検証（各タスクのコミット前に必ず実行）

```bash
cd /Volumes/DevSSD/Development/Projects/Memora/apps/mobile-expo
npm test
npm run typecheck
npx expo export --platform web
```

さらにリポジトリのルートで:

```bash
cd /Volumes/DevSSD/Development/Projects/Memora
git diff --check
```

**いずれかが失敗したら、そのタスクの変更を元に戻して次のタスクへ進んでください。**
失敗を抱えたまま先に進まないこと。

### 注意: 実行してはいけない検証

- `npm run qa:ios:build` — iOS ビルド。時間がかかるうえ、あなたの環境では失敗する可能性が高い
- `xcodebuild` / `xcrun simctl` — シミュレータ操作。**実機確認は別の担当が行います**

---

## 7. コミット

- **タスクごとにコミットを分けてください**
- コミットメッセージは日本語で構いません
- **1行目に何をしたか、本文になぜそうしたかを書いてください**
- `git push` は**しないでください**
- `apps/mobile-expo/ios/Podfile.lock` は**ステージしないでください**

もし `git commit` が
`fatal: Unable to create '.git/index.lock': Operation not permitted`
で失敗する場合は、**再試行せず**、変更を作業ツリーに残したまま報告してください。

---

## 8. 判断に迷ったときのルール

**推測で直さないでください。**

- 仕様が分からない → 変更せず報告
- デザインの意図が分からない → 変更せず報告
- 見た目が変わりそう → 変更せず報告

「変更しなかったこと」は失敗ではありません。
**根拠なく変更して壊すことのほうが問題です。**

---

## 9. 報告

`docs/agent-workflows/opencode-handoff-2026-08-16-result.md` に書いてください。

含めるもの:

- **タスクごとに**:
  - 実施した内容
  - 変更したファイル
  - 検証結果（実行したコマンドと pass / fail）
  - コミットハッシュ（コミットできなかった場合はその旨）
- **判断保留にしたものの一覧と、その理由**（**最重要**。次の担当者の起点になります）
- タスクA: 追加したテストの件数と、追加後の合計件数
- タスクE: 未実装導線の一覧表
- タスクB / C / D: 作業後に grep を再実行した残件数
- **着手できなかったタスクと、その理由**

最後に次の2つの出力を貼ってください:

```bash
git status --short
git log --oneline origin/main..HEAD
```
