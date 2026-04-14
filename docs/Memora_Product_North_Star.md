# Memora Product North Star

> この文書を、今後の **最上位の簡易仕様書** とする。  
> 迷ったらまずこれを読む。細かい旧 docs よりも、この文書と `CLAUDE.md` を優先する。

## 1. Memora は何のアプリか

**Memora は、PLAUD Note ライクな「個人向け meeting OS」** である。  
ユーザーは音声を **録る / 取り込む**。その後アプリが **文字起こし → 要約 → メモ整理 → AI 質問 → 外部共有** まで一気通貫で支援する。

一言で言うと、

**「会議・打ち合わせ・講義・インタビューの内容を、あとで使える知識に変えるアプリ」**

である。

## 2. 今の開発で絶対にブレてはいけない体験

### 体験 1: ちゃんと録れて、落ちずに文字起こしできる
- 録音または音声取り込みができる
- 文字起こし実行でクラッシュしない
- 長時間音声でも途中で破綻しにくい
- 失敗時に「なぜ失敗したか」がわかる

### 体験 2: 1ファイルを見返しやすい
- 録音ファイル詳細で **Summary / Transcript / Memo** を切り替えられる
- Memo は Markdown で書ける
- 写真を添付できる
- 要約・文字起こし・メモ・写真が、1つの記録としてまとまる

### 体験 3: あとから AI に聞ける
- **File** 単位で質問できる
- **Project** 単位で質問できる
- **Global** 単位で質問できる
- 使うほどアプリ内メモリでパーソナライズされる

### 体験 4: 外に持ち出せる
- Markdown / TXT / JSON / SRT / VTT で出せる
- Notion や ChatGPT など、他サービス側に知識を貯められる
- まずは「export で繋ぐ」。重い常時同期は後回し

## 3. すでに土台があるもの（作り直さない）

以下は「ゼロから再設計しない」。不足があれば **磨く / 繋ぐ / 安定化する**。

- 録音
- 音声ファイル import
- 文字起こし
- 要約
- プロジェクト管理
- ToDo 管理
- File Detail のタブ型 UI
- Markdown メモ
- 写真添付
- AskAI の file / project / global スコープ
- Plaud / Omi 関連の土台
- 各種 export

## 4. 今やること / まだやらないこと

### 今やること
1. **文字起こしクラッシュを止める**
2. AskAI を「本当に使える」状態にする
3. AI がタスクを分解・整理できるようにする
4. Notion / ChatGPT など外部への知識蓄積導線を作る
5. 起動の重さを減らす

### 後回しにすること
- サインイン
- ペイウォール
- オンボーディング大型刷新
- 本格クラウド同期
- 会議 bot
- watch 単体録音
- デスクトップ / Web 録音の本格実装

## 5. 今のプロダクトの優先順位

### P0: Reliability
- STT 実行で hard crash しない
- 起動が重すぎない
- 失敗理由が見える

### P1: AI Workspace
- AskAI が file / project / global で成立する
- Personal memory が効く
- AI task decomposition が使える

### P2: Context Export
- Notion / ChatGPT 向けに summary / memo / transcript を外へ出せる
- 後でコンテキストを蓄積しやすい

### P3: Capture Expansion
- online meeting coverage
- Apple Watch
- desktop / web 補助

### P4: Business Layer
- sign in
- onboarding v2
- paywall
- paid cloud storage

## 6. 開発判断ルール

- **新機能より安定性優先**
- **大きい再設計より、今ある土台を product path に揃える**
- **1 PR = 1成果物**
- **今 sprint で効かない未来機能は切る**
- **STT が落ちる間は、他機能を最優先にしない**

## 7. vNext の完成条件

次の区切りで「前進した」と言えるのは、以下が揃った時。

1. 文字起こしでクラッシュしにくくなる
2. File Detail が日常的に使える
3. AskAI が file / project / global で意味のある回答を返す
4. AI がタスク整理まで支援する
5. Notion / ChatGPT へ持ち出す導線ができる

## 8. Claude への一言での説明

> Memora は「PLAUD Note ライクな個人向け meeting OS」です。  
> いま最優先は STT 安定化、その次が AskAI を本当に使える状態にすることです。  
> 既存機能を壊さず、最小差分で product path を完成させてください。
