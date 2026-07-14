# Memora Speed Plan

> この文書は **開発速度を上げるための簡易実行計画**。  
> これと `Memora_Product_North_Star.md` だけを見れば、Claude が次に何をやるべきか判断できるようにする。

## 0. この計画の使い方

- まず `CLAUDE.md` を読む
- 次に `Memora_Product_North_Star.md` を読む
- 最後にこの文書を読む
- 旧 docs は、**そのファイルを触る時だけ参考にする**
- 迷ったら **P0 → P1 → P2** の順で進める

## 1. 現在地

### すでにあるもの
- 録音 / import / STT / 要約 / プロジェクト / ToDo の土台
- File Detail の Summary / Transcript / Memo タブ
- Markdown メモ
- 写真添付
- AskAI の scope UI
- export 系

### まだ弱いもの
- 文字起こしの安定性
- AskAI の retrieval 品質
- AskAI personalization
- AI task decomposition の product 化
- 外部サービスへの知識蓄積導線
- 起動性能

## 2. これからの大きな開発テーマ

## Epic A — STT Reliability
**目的:** 文字起こしで落ちないことを最優先で達成する。

### この Epic でやること
- SpeechAnalyzer / legacy fallback の再点検
- crash 再現条件の特定
- preflight / availability / format / locale / asset の安全化
- 失敗理由を UI または debug log で見える化
- regression を防ぐ軽い tests / smoke checks

### Done 条件
- 文字起こし実行で hard crash が再現しにくい
- 失敗しても fallback または明示エラーで止まる
- 再現ログが取れる

### Status
- DONE

---

## Epic B — AskAI Usable
**目的:** AskAI を「あるだけ」から「使える」へ引き上げる。

### この Epic でやること
- file / project / global で context を適切に組む
- transcript / summary / memo / photo OCR / todo を束ねる
- lightweight retrieval を service 化する
- AskAIView から context 構築責務を外す

### Done 条件
- file / project / global の回答品質差が説明できる
- 回答に使った context が追える
- UI より service が中心になる

### Status
- DONE

---

## Epic C — Personal Memory + Task Decomposition
**目的:** AskAI を使うほど賢くなり、タスク整理まで手伝えるようにする。

### この Epic でやること
- app-owned personal memory の保存・参照
- user preference / output format / task granularity の記憶
- AI による task decomposition
- 生成されたタスクを Todo に落とし込む導線

### Done 条件
- AskAI が前回までの好みを反映できる
- 会議内容から subtasks を提案できる
- Todo 作成に繋がる

### Status
- DONE

---

## Epic D — Context Export Connectors
**目的:** Memora の知識を外に流して、別サービス側でも文脈が育つようにする。

### この Epic でやること
- Notion 向け export
- ChatGPT / OpenAI 向け export 方針整理
- summary + transcript + memo + todo を一塊で出せるようにする
- まずは export / share 中心で作る

### Done 条件
- 1記録を外に持ち出しやすい
- 他サービスで知識蓄積しやすい
- 重い常時同期なしで価値が出る

### Status
- DONE

---

## Epic E — Capture Expansion
**目的:** オフライン会議以外もカバー範囲を広げる。

### この Epic でやること
- online meeting capture contract の hardening
- Chrome 拡張での tab audio capture / chunk upload / recovery
- cloud transcription / summary worker
- Google Meet / Zoom / Teams の post-meeting artifact import
- visible participant Bot の platform adapter
- calendar awareness
- Apple Watch remote / standalone record
- desktop helper

### Done 条件
- Chromeで60分会議を録音し、transcript / summary / todo が生成される
- 同じ会議が Memora の1つの File Detail に入る
- post-meeting artifact import が最低1プラットフォームで動く
- visible participant Bot が最低1経路で end-to-end 動く
- consent / retention / delete がユーザーから確認できる

### Status
- IN_PROGRESS（Google Meet インポート UI、Bot server / iOS scheduling skeleton あり。実参加 adapter と Chrome 拡張は未着手）

### Source of truth
- `docs/online-meeting-capture-plan.md`

---

## Epic F — Business Layer
**目的:** 最後に monetization と account layer を足す。

### この Epic でやること
- sign in with Apple / Google
- onboarding v2
- paywall
- free local / paid cloud storage 導線

### Done 条件
- プロダクトが安定してから着手

### Status
- BACKLOG

## 3. Claude が今すぐやる順番

1. 完了済み Epic A〜D の回帰を守る
2. Epic E の capture contract hardening
3. Chrome capture PoC
4. chunk upload + transcription / summary worker
5. Google Meet productization / artifact import
6. participant Bot MVP
7. Epic F は Capture Expansion の product path が成立するまで後ろに置く

## 4. 1セッションのルール

- 1セッション = 1 PR
- 1PR で 1 Epic を全部終わらせようとしない
- Epic を **1つの意味ある成果** に分ける
- broad rewrite 禁止
- UI 変更は必要最小限

## 5. Claude が毎回やること

### セッション開始時
- 現在の codebase を読む
- `CLAUDE.md` を読む
- `Memora_Product_North_Star.md` を読む
- この文書を読む
- 最高優先の未完了 Epic を選ぶ

### セッション終了時
- 何を進めたかを書く
- 次に進むべき Epic を明記する
- この文書の Status を必要なら更新する

## 6. 迷った時の判断

- STT crash が残るなら **Epic A に戻る**
- AskAI の質が低いなら **Epic B に戻る**
- タスク分解と memory は **Epic B の後**
- Notion / ChatGPT 連携は **Epic C の後**
- online meeting は `online-meeting-capture-plan.md` の OM-0 → OM-8 順
- watch は Chrome / Bot と独立した target として進め、STT コアへ直接入れない
- sign in / paywall は Capture Expansion の product path が成立するまで後ろ
