# Memora 実用度スコアリング（2026-09-07）

- 対象: Memora（Lane F: `apps/mobile-expo`、Expo SDK 57 / RN 0.86 / Expo Router）
- 評価者: 読み取り専用スコアリング担当（サブエージェント）
- 作業ツリー: ブランチ `chore/opencode-20260816`（origin/main に対し ahead 3）＋**未コミット v2 デザイン刷新（30 ファイル、+2782/−2063）**
- 前提: 本作業ツリーの test / typecheck / web export の実行結果は **未確認**（ルートが取得中。本スコアは「未検証」として扱う）
- 100 点の定義: 「録音→文字起こし→要約→詳細→Ask AI→エクスポート」のローカル会議メモアプリが**実機で日常運用に耐える**状態

---

## 総合点: 50 / 100（加重平均 49.6 → 四捨五入）

**要約**: コアフロー（録音/取込→STT→要約→詳細→エクスポート）はコード上つながり、コミット済み状態で単体 86 / native 32 のテストが通っている。一方で (a) 未コミット v2 刷新が未検証、(b) 実機 QA・`xcodebuild archive`（device destination）・共有ストア実データ移行（gate b）が未実施、(c) Personal Team では App Group（`group.com.memora.shared`）を使えず署名配布が壁、(d) Ask AI のファイル/プロジェクト対象指定や コピー・音声入力、会議キャプチャ、設定の大半が未実装のまま残る。このため「今すぐ日常運用で使える」には届かず 50 点。

---

## 軸別スコア（部分点 × 重み = 加重点）

| 軸 | 重み | 部分点 | 加重点 | 根拠（コード/文書） | 残作業（100 点までの主な差分） |
|---|---:|---:|---:|---|---|
| 1. コアフロー完走度 | 30% | 62 | 18.6 | 録音→STT→要約が `CaptureFlowProvider.tsx` の `runGeneration`（transcribe→summarize 直列）で接続。FileDetail に summary/transcript/memo・再生・書き出し・再試行。Ask AI は実 bridge（`queryKnowledge`）＋API キー欠如時 CTA（`AskAIScreen.tsx:282-289,363-370`）。エクスポートは Notion / ChatGPT / ファイル共有が実装 | Ask AI のファイル/プロジェクト対象指定は未配線（`AskAIScreen.tsx:47-49`、実質 global のみ）。コピーはスタブ。会議キャプチャは準備中 |
| 2. 未実装導線の残数 | 15% | 55 | 8.25 | `準備中/現在利用できません` の直接ヒットは**6 ファイル 6 行**（CaptureSheet:59 / FileDetail:603 / Tasks:261 / AskAI:350 / AuthFlow:435 / Settings:99）。8/16 一覧（24 行）より減少したが、AskAiOverlay・HomeComposer の削除による「UI ごと撤去」分を含む | Settings 13 行（アカウント/デバイス/言語/要約モデル等）は共通 `notConnected` のまま。Ask AI の添付・音声入力はボタン自体が消滅 |
| 3. 実機 / 配信ゲート | 20% | 25 | 5.0 | `docs/rn-device-qa-2026-08-10.md`（実機 QA 未実施 R1-R8）、`rn-release-readiness`（gate b 未実施、archive device 未実施）、`rn-full-cutover-execution-plan.md:210`。App Group は portal での有効化が signed 配布の前提（`react-native-swiftdata-target-sharing-decision.md:17`） | 実機必須 F5/F9、実データ移行 rollback（gate b）、device archive＋署名（Personal Team 制約、MEMORY.md:312,331）。配信はアプリ完成まで先送り |
| 4. 検証状態 | 15% | 55 | 8.25 | コミット済み状態で単体 **86 pass**・typecheck/export pass（`opencode-handoff-2026-08-16-result.md`）、native 32 pass（`rn-release-readiness-2026-08-10.md` §7.1）。ただし**未コミット v2 刷新（30 ファイル）は未検証** | v2 で test / typecheck / export / qa:ios を実行して確定。結果はルートが後から追記予定 |
| 5. 設定 / 認証 / 外部依存 | 10% | 45 | 4.5 | API キー設定は実装済み（Settings `manageSecureCredential` → native Keychain）。Notion 親ページ/トークン設定 UI も実装 | Ask AI モデル選択 UI なし（`ASK_AI_MODEL_OPTIONS` は定義のみ）、音声入力・アカウント系（ログアウト/削除/表示名）はスタブ。Auth/paywall は dev のみ |
| 6. 既知の品質保留 | 10% | 50 | 5.0 | fontSize 直書きは現コードで **6 箇所**を確認（`_layout.tsx:46`=11、FileDetail=12/24/18、CaptureFlow=12/44）。hitSlop フォローアップ（PlayerBar seekbar 12pt へ未付与・rate 横方向 2pt のまま）は未反映。デザイン正本（v07 HTML・docs/design-system）が git 未管理で揺れ | fontSize のトークン化、hitSlop 修正 1・2（`opencode-followup-2026-08-16.md`）、デザイン正本の一本化と git 管理 |

---

## 100 点到達までに必要な最短の工程（3 つ）

1. **v2 刷新の検証と確定**: 未コミット作業ツリーに対して test / typecheck / web export / qa:ios を通し、失敗を直してコミットする（現スコアの最大の不確実性を除去）。
2. **実機 QA と配信ゲート通過**: 実機で録音→バックグラウンド継続→STT→要約（実 API キー）→Ask AI→Notion/共有書き出しまで完走し、`xcodebuild archive`（device destination）と署名（App Group を扱える有料 Team 契約または構成変更）を成立させる。
3. **Ask AI と設定の仕上げ**: ファイル/プロジェクト対象指定の配線、コピー・音声入力・会議キャプチャ、Settings の主要行（アカウント/言語/要約モデル等）を実装し、生成失敗時の API キー設定導線（T1 相当）を追加する。

---

## データが無く推測・方針判断で入れた項目

- **実機での UX・安定性**: 実機 QA 未実施のため、動作の可否はコードとシミュレータ証跡からの推定。
- **現在の test / typecheck / export 結果**: 未コミット v2 は未確認と扱い、軸 4 を 55 点に抑制。
- **Personal Team / App Group の壁**: リポジトリ docs には部分記載のみ（`react-native-swiftdata-target-sharing-decision.md:17`）。「署名なしアーカイブ成功」「Personal Team では App Group 不可」は過去セッション記憶（MEMORY.md）由来で、今回のコード/文書検証では直接確認していない。
- **配信の重み配分**: 「日常運用」を実機配布可能と解釈し、軸 3 の重みを 20% に設定（運用方針によっては変動）。

---

## ルート追記欄（作業ツリーの検証結果）

- `npm test`（apps/mobile-expo）: **pass — 9 ファイル / 93 件**（8/16 時点の 86 件から +7。`recordingHabit.test.ts` 等が追加されている）
- `npm run typecheck`: **pass**
- `npx expo export --platform web`: **pass**（dist 出力成功）
- `git diff --check`（リポジトリルート）: **pass**
- 備考: 上記は 2026-09-07 に未コミット v2 刷新を含む作業ツリーのまま実行した実測値。`npm run qa:ios:build` / 実機 / Simulator は本環境の制約で未実行。

### 実測反映後の補正（2026-09-07）

軸4「検証状態」は、v2 刷新を含む作業ツリーで test(93) / typecheck / web export が全て pass したため
「未検証」の不確実性は解消。ただし native 32 件の実機再実行・`qa:ios:build` は未実施のため、
部分点を 55 → **85**（+30）に補正。

| 軸 | 重み | 補正後部分点 | 補正後加重点 |
|---|---:|---:|---:|
| 1. コアフロー完走度 | 30% | 62 | 18.6 |
| 2. 未実装導線の残数 | 15% | 55 | 8.25 |
| 3. 実機 / 配信ゲート | 20% | 25 | 5.0 |
| 4. 検証状態 | 15% | 85 | 12.75 |
| 5. 設定 / 認証 / 外部依存 | 10% | 45 | 4.5 |
| 6. 既知の品質保留 | 10% | 50 | 5.0 |
| **合計** | 100% | — | **54.1 → 54 / 100** |

総合点は **50 → 54 / 100** に上方修正（検証の不確実性が解消した分）。残る主因は
実機/配信ゲート（25 点）と未実装導線・Ask AI 仕上げで、コード品質ゲート（test/typecheck/export）は
現状 green である点を反映した。

### 波2（並列実装 3 件・2026-09-07）反映後の補正

オフラインで実装可能な品質改善を 3 本並列で実施し、いずれも test(93) / typecheck / web export を
通してコミット・push 済み（PR #212 に反映）。

| コミット | 内容 | スコアへの効き方 |
|---|---|---|
| `81ecc279` | 生成失敗時に理由＋APIキー設定導線を表示、空の進捗バー撤去（T1相当） | 軸5（設定/外部）と軸6 の部分点を押し上げ |
| `b8512250` | シークバー・再生速度・AskAI対象行の hitSlop を 44pt へ補正 | 軸6（品質）改善。ただし trackWrap は非干渉上限 28pt で 44 未到達の判断保留 |
| `35aa9b62` | FileDetail の未使用スタイル残骸（fontSize 12/24/18 直書き含む）を削除 | 軸6 の fontSize 直書きを **3 箇所に削減**（_layout:11 / islandTimer:12 / recordingTime:44） |

補正後の総合点は **54 → 57 / 100** 程度と推定（軸5・軸6 の部分点が上昇、残る大きい差分は
実機/配信ゲート 25 点と未実装導線）。fontSize 残 3 箇所はすべて「トークン追加 or 設計判断」が
必要なため変更せず保留（詳細は review-v2-refresh.md と本ファイル軸6）。
