# RN 実機 QA 手順書（2026-08-10）

- 状態: 運用中（実機 QA は未実施）
- 作成: 2026-08-10
- 担当 lane: E（QA / 運用）・G（RN ネイティブ）
- 上位文書: `docs/decisions/ADR-003-rn-full-cutover.md`（gate a〜e）、`docs/rn-full-cutover-execution-plan.md`（実行計画）
- 続きの正本: parity matrix の現在地は `docs/rn-full-cutover-execution-plan.md`、リリース準備監査は
  `docs/rn-release-readiness-2026-08-10.md`

## 1. 目的

Memora RN ホスト（`apps/mobile-expo`、bundle ID `com.memora.Memora`）の 1.0 対象フローを
実機で検証するための手順書。各項目に「シミュレータで検証可能 / 実機必須」を明記し、
手順・期待結果・受入基準・証跡保存先を定義する。

検証結果は本手順書の「§6 実施記録」へ追記し、ADR-003 gate a〜e の evidence とする。

### 関連付け（ADR-003 gate a〜e と Lane E / G）

| 対象フロー | gate | Lane |
|---|---|---|
| 録音 → STT → 要約 → 再生 | a（core parity）/ e（実機 QA） | E / G / B / C |
| インポート import | a / e | E / G |
| バックグラウンド録音 | d（バックグラウンド録音申告）/ e | E / G |
| マイク / 音声認識権限 | d（usage description）/ e | E / G |
| Tasks | a / e | E / G / F |
| Ask AI 検索 | a（search）/ e | E / G / C |
| Notion / ChatGPT 設定行 | a（export の一部。実連携は別 PR） | E / F |

## 2. 検証対象と区分の一覧

凡例:
- **シミュレータで検証可能**: シミュレータ（`Memora RN Test`、iOS 26.5）で実行できる
- **実機必須**: シミュレータでは再現できない（ロック画面・実 API・実マイク精度など）

| # | フロー | 区分 | 概要 |
|---|---|---|---|
| F1 | 録音 → 一覧反映 | シミュレータで検証可能 | 録音開始/停止 → 一覧へ反映 → 再起動後も残存 |
| F2 | STT（文字起こし） | シミュレータで検証可能（精度は実機推奨） | 実音声の文字起こし → File Detail の文字起こしタブ表示 |
| F3 | 要約 summary | シミュレータで検証可能（実 API キー必須） | `generateSummary` → File Detail の概要表示 |
| F4 | 再生 playback | シミュレータで検証可能 | 録音の再生・seek・rate |
| F5 | バックグラウンド録音 | **実機必須** | 録音中にホーム/ロックへ → 復帰 → 録音継続・ファイル保存（#188 で `UIBackgroundModes: audio` 追加済み） |
| F6 | マイク / 音声認識権限 | シミュレータで検証可能（初回許可ダイアログは実機必須） | 権限フローと拒否時の挙動 |
| F7 | インポート import | シミュレータで検証可能 | ファイル取込 → 一覧反映 → 永続化 |
| F8 | Tasks | シミュレータで検証可能 | タスク CRUD・期限グループ・完了折りたたみ |
| F9 | Ask AI 検索 | **実機必須**（実 API キー必須、#189 で実データ配線済み） | Settings で API キー設定 → global 質問 → 実データ回答 + sources 表示 → 品質チェック |
| F10 | Notion / ChatGPT 設定行 | シミュレータで検証可能（表示のみ） | Settings「連携」行の「1.0 対象（準備中）」表示・未接続 Alert の確認。実連携は別 PR（`docs/rn-export-contract-2026-08-10.md`） |

## 3. 実行環境と準備

### 3.1 シミュレータ（煙試験・シミュレータ検証項目用）

- シミュレータ: "Memora RN Test"（UDID `55B313C9-3F8F-411E-843D-CC662E2DCD2A`、iOS 26.5）
- ビルド: `npm run qa:ios:build`（分離 DerivedData `apps/mobile-expo/.expo/ios-qa-derived-data`）
- インストール: `xcrun simctl install 55B313C9-3F8F-411E-843D-CC662E2DCD2A <DerivedData>/Build/Products/Debug-iphonesimulator/MemoraRN.app`
- 起動: `xcrun simctl launch 55B313C9-3F8F-411E-843D-CC662E2DCD2A com.memora.Memora`
- 権限付与（煙試験用）: `xcrun simctl privacy 55B313C9-3F8F-411E-843D-CC662E2DCD2A grant all com.memora.Memora`
- スクリーンショット: `xcrun simctl io 55B313C9-3F8F-411E-843D-CC662E2DCD2A screenshot <path>`

### 3.2 実機（F5 / F9 ほか実機必須項目用）

- 端末: iPhone（iOS 17 以上推奨。iOS 17.0 が最低サポート target）
- ビルド: `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'platform=iOS,name=...' -derivedDataPath <path> build`
  （実機署名は Development Team 設定済みであること。詳細は Lane D / G 担当）
- 注意: **API キーをログ / スクリーンショット / PR に含めない**（F3 / F9 参照。QA 用の使い捨てキーを使い、検証後は失効させる）

## 4. フロー別 手順・期待結果・受入基準・証跡保存先

証跡保存先は `.expo/qa-evidence-2026-08-10/`（ローカル管理。`.expo/` は gitignore 対象）。
ファイル名は `NN-<フロー>-<内容>.png` / ログは `.log`。

### F1 録音 → 一覧反映（シミュレータで検証可能）

手順:
1. アプリを起動し Home の FAB（+）から録音開始。
2. 数秒待機して停止（stop）し、保存。
3. Home 一覧に録音が反映されることを確認。
4. アプリを再起動（シミュレータで `terminate` → `launch`）し、一覧に残っていることを確認。

期待結果:
- 録音開始/停止・一時停止/再開が正常に動作し、共有 SwiftData ストア（`group.com.memora.shared`）へ永続化される。
- 一覧のタイトル・日時・ステータス（録音 → 処理中 → 完了）が更新される。

受入基準:
- 録音 → 一覧反映 → 再起動後も残存。
- パリティマトリクスの「録音 record」受入条件（`docs/rn-full-cutover-execution-plan.md` §4）を満たす。

証跡: 一覧画面スクリーンショット、再起動後一覧スクリーンショット。

### F2 STT（文字起こし）（シミュレータで検証可能。精度は実機推奨）

手順:
1. F1 で作成した録音を File Detail で開く。
2. 文字起こしタブから STT を開始し、完了を待つ。
3. transcript の表示・`cleanedText` 切替・segment tap での seek + 再生を確認。

期待結果:
- `MemoraRNTranscriptionBridge` → `STTService`（SFSpeechRecognizer）が実音声を文字起こしし、
  共有 SwiftData `Transcript` へ persist され、File Detail の文字起こしタブに実データが表示される。
- セグメントタップで該当時刻へ seek して再生される。

受入基準:
- 実録音の文字起こしが RN transcript タブに表示される（parity matrix「STT」受入条件）。
- シミュレータではマイク入力にシステム音声が使われるため**精度は判定しない**（実機で精度確認）。

証跡: 文字起こしタブのスクリーンショット。

### F3 要約 summary（シミュレータで検証可能。実 API キー必須）

手順:
1. Settings で要約プロバイダ（API キー）を設定する（実 API キー、Keychain 保存）。
2. 文字起こし済みのファイルを File Detail で開き「要約」を実行。
3. 概要（Markdown）が表示されることを確認。

期待結果:
- `MemoraSharedStoreSummaryGenerator` → `generateSummary` bridge が API キー（Keychain `com.memora.app`）で
  要約を生成し、File Detail の概要に実データが表示される。
- API キー未設定時はエラー / 設定導線が提示される。

受入基準:
- 実ファイルの要約が RN File Detail に出る（parity matrix「要約 summary」受入条件）。
- **実 API キーでの実行は実機必須（F9 の Ask AI と共通の資格情報）**。シミュレータで実行する場合は
  QA 用の使い捨てキーを使い、ログにキーを出さない。

証跡: 概要タブのスクリーンショット。

### F4 再生 playback（シミュレータで検証可能）

手順:
1. 録音を File Detail で開き PlayerBar で再生。
2. seek・再生レート変更・transcript との連動（セグメントタップ）を確認。

期待結果:
- `MemoraAVAudioPlaybackController` が再生・seek・rate を正常に処理する。

受入基準:
- 実録音の再生・seek・rate が成立（parity matrix「再生 playback」受入条件）。

証跡: 再生中の PlayerBar スクリーンショット。

### F5 バックグラウンド録音（**実機必須**）

> #188 で `UIBackgroundModes: audio` を app.json と RN ホスト Info.plist の両方に追加済み。
> 割り込み終了時の録音再開（`AVAudioSession.interruptionNotification`）も実装済み。
> シミュレータではロック画面 / バックグラウンドでの音声継続を正しく再現できないため**実機必須**。

手順:
1. 実機で録音を開始する。
2. そのままホーム画面（App Switcher / ホーム）へ移動する。
3. 電源ボタンで画面をロックし、数十秒〜数分待つ。
4. ロックを解除してアプリへ復帰する。
5. 録音が継続されている（または正常に保存されている）ことを確認し、停止してファイルを確認する。

期待結果:
- バックグラウンド / ロック中も録音が継続し、復帰時に録音画面が正しい状態（経過時間・波形）を表示する。
- 停止後のファイルが Home 一覧に反映され、再生できる。
- 割り込み（着信等）が発生した場合は復帰後に録音が再開される。

受入基準:
- ロック中に録音が途切れず、復帰 → ファイル保存 → 再生まで成立する。
- 審査申告（`UIBackgroundModes: audio`）と実際の動作が一致している（gate d の実機確認）。

証跡: ロック前後の録音画面スクリーンショット、保存ファイル一覧スクリーンショット、録音ログ。

### F6 マイク / 音声認識権限（シミュレータで検証可能。初回許可ダイアログは実機必須）

手順:
1. クリーンインストール状態（権限未付与）で録音を開始する。
2. マイク / 音声認識の初回許可ダイアログが出ることを確認し、許可・拒否それぞれの挙動を確認。
3. 拒否した場合のエラー表示と設定画面への導線を確認。

期待結果:
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` に従ったダイアログが表示される。
- 許可後は録音・STT が動作し、拒否時は適切なエラーと権限設定への案内が表示される。

受入基準:
- 権限フローの表示文言と挙動が gate d（privacy）の要求を満たす。
- シミュレータでは `xcrun simctl privacy ... grant/deny` で状態を切り替えて検証可能。
- **実機では初回起動時のダイアログ表示タイミングと文言を確認する（実機必須）**。

証跡: 許可ダイアログ / 拒否時エラーのスクリーンショット。

### F7 インポート import（シミュレータで検証可能）

手順:
1. シミュレータへ音声ファイル（m4a / wav 等）を `simctl addmedia` で追加する（または Files アプリ経由）。
2. Home のインポートからファイルを選択し、取り込む。
3. 一覧へ反映され、再生・STT が動作することを確認。
4. アプリを再起動して永続化を確認。

期待結果:
- `expo-document-picker` → `importAudio` bridge が共有 SwiftData ストアへ永続化する。

受入基準:
- 実ファイル取込 → 一覧反映 → 永続化（parity matrix「インポート import」受入条件）。

証跡: インポート後の一覧スクリーンショット。

### F8 Tasks（シミュレータで検証可能）

手順:
1. Tasks タブでタスクを作成（タイトル・期限・ソース音声紐づけ）。
2. 期限グループ表示・完了折りたたみ・編集・削除を確認。
3. アプリを再起動して永続化を確認。

期待結果:
- `TodoItem`（共有 SwiftData）+ `MemoraSharedStoreTaskBridgeAdapter` で CRUD が実データに反映される。
- `sourceAudioFileId` を持つタスクは Home の録音タイトルと紐づき、タップで `file/[id]` へ遷移する。

受入基準:
- タスクの実データ契約（#180）に基づく CRUD・永続化が成立。
- 未接続の導線（「日付を選択」・FileDetail「タスクに追加」・AskAI「タスク化」は Alert のみ）は現状どおり。

証跡: Tasks 一覧 / 作成 / 完了のスクリーンショット。

### F9 Ask AI 検索（**実機必須**・実 API キー必須）

> #189 で Ask AI は実データ（global スコープ）回答とサンプル標識へ配線済み。1.0 対象かは判定待ち。

手順:
1. Settings で API キーを設定する（Ask AI 用。Keychain に保存。**ログや PR に表示しない**）。
2. Ask AI タブでスコープを global に切り替える。
3. 実データに基づく質問（例: 過去の録音内容に言及する質問）を投げ、回答を確認する。
4. 回答と併せて **sources（出典ファイル）が表示される**ことを確認する。
5. 品質チェック: 実際の録音内容と照合し、回答の正確性・引用の妥当性を確認する。

期待結果:
- `queryKnowledge` bridge → `MemoraSharedStoreKnowledgeQuery` → `LocalRetrievalEngine` が
  実データ（共有 SwiftData の録音 / transcript / 要約）を検索し、回答 + sources を返す。
- スコープ（global / ファイル単位）の切替が意図どおり動作する。

受入基準:
- Ask で実検索結果（実データに基づく回答 + sources 表示）が返る（parity matrix「検索 search」受入条件）。
- retrieval 品質の目視チェック（誤引用・関連性の低い source が混ざらないこと）。
- **シミュレータでは実 API キーを使う必要があるため、実機での検証を推奨（実機必須）**。

証跡: 質問と回答 + sources のスクリーンショット（API キーが写らないよう注意）。

### F10 Notion / ChatGPT 設定行（シミュレータで検証可能・表示のみ）

手順:
1. Settings「連携」グループを開く。
2. 「Notion に書き出す」「ChatGPT に共有」の行の表示を確認する。
3. File Detail の書き出しシートの「Notion に転記」「ChatGPT に共有」の表示を確認する。

期待結果:
- 未接続時は「1.0 対象（準備中）」と表示され、タップで未接続 Alert が出る
  （`docs/rn-export-contract-2026-08-10.md` の契約に準拠した文言）。
- 実連携は別 PR（OAuth / API 呼び出し）のため本手順書では表示確認のみ。

受入基準:
- 設定行・書き出しシートの文言と挙動が export 契約と一致する。

証跡: Settings「連携」セクションのスクリーンショット。

## 5. 既知リスク・未検証事項

| # | リスク / 未検証 | 区分 | 備考 |
|---|---|---|---|
| R1 | 実機未接続（iPhone が未接続・実機ビルド未実施） | 実機必須 | 実機 QA 開始前に Device 接続と署名設定の確認が必要 |
| R2 | バックグラウンド録音のロック検証 | 実機必須 | シミュレータでは再現不可。`UIBackgroundModes: audio` は #188 で追加済みだが動作の実機確認は未実施 |
| R3 | Ask AI（F9） | 実機必須 | 実 API キー必須。シミュレータでも実行可能だが実データ量・品質確認は実機推奨 |
| R4 | STT 精度・話者分離 | 実機推奨 | シミュレータはシステム音声入力のため精度判定不可 |
| R5 | マイク / 音声認識の初回許可ダイアログ | 実機必須 | シミュレータは `simctl privacy` で制御可能だが、実機の初回表示タイミング・文言は要確認 |
| R6 | 共有ストア移行（gate b）の実機検証 | 実機必須 | ADR-004 実装済みだが実データ移行・rollback の実機検証は未実施 |
| R7 | 要約（F3）の API キー実接続 | 実機推奨 | Keychain 経由の実キーで要約を実機確認（QA 用使い捨てキー推奨） |
| R8 | Notion / ChatGPT 実連携 | 実装前 | 別 PR（export 契約は `docs/rn-export-contract-2026-08-10.md`） |

## 6. 実施記録

### 6.1 シミュレータ煙試験（2026-08-10）

| 項目 | 結果 | 証跡 |
|---|---|---|
| `npm ci` | pass | — |
| `npm run typecheck` | pass | — |
| `npm test`（42 件） | pass | — |
| `CI=1 npx expo export --platform web` | pass | — |
| `npm run qa:ios:build` | pass（Debug-iphonesimulator / arm64） | DerivedData `apps/mobile-expo/.expo/ios-qa-derived-data` |
| シミュレータ install（`MemoraRN.app`） | pass | — |
| launch `com.memora.Memora` | pass（起動ログあり、Dev Client の起動画面を確認） | 起動証跡: `.expo/qa-evidence-2026-08-10/01-launch-home.png` |
| 権限付与（マイク / 音声認識 / フォト） | pass（`simctl privacy grant all`） | — |

- 実施端末: シミュレータ "Memora RN Test"（55B313C9-3F8F-411E-843D-CC662E2DCD2A、iOS 26.5）
- 実施日: 2026-08-10（ローカル。CI 最終ゲートは GitHub Actions）

### 6.2 RN ホスト native テスト（2026-08-10）

```bash
MEMORA_RN_DESTINATION="platform=iOS Simulator,name=Memora RN Test,OS=26.5" npm run qa:ios:test
```

- 実行: `test-without-building`（再ビルド不要。分離 DerivedData `apps/mobile-expo/.expo/ios-qa-derived-data` を使用）
- 結果: **19 tests 全 pass（Passed / 19 passed / 0 failed / 0 skipped）**。exit code 0。
  （`xcrun xcresulttool get test-results summary` で確認。`.xcresult`: `Logs/Test/Test-MemoraRN-*.xcresult`）
- 実行先: シミュレータ "Memora RN Test"（55B313C9-3F8F-411E-843D-CC662E2DCD2A、iPhone 17 Pro / iOS 26.5）

| Suite | テスト | 結果 |
|---|---|---|
| RN summary bridge security（`MemoraSummaryBridgeSecurityTests.swift`） | Keychain失敗とDTOは秘密文字列をJS境界へ出さない / 鍵入力・状態・削除のJS境界は秘密文字列を返さない / 共有要約結果をSwiftDataへ保存する | 3 passed |
| RN shared store task bridge adapter（`MemoraSharedStoreBridgeAdapterTests.swift` 内） | unknown IDs fail safely / create, list, toggle, update, and delete persist / due dates and source links survive DTO round trip | 3 passed |
| RN shared store bridge adapter（`MemoraSharedStoreBridgeAdapterTests.swift` 内） | invalid IDs・playback path・transcript DTO・processing retries・rename/move/delete・custom vocabulary・mock source ほか | 11 passed |
| RN SpeechAnalyzer bridge（`MemoraSharedStoreBridgeAdapterTests.swift` 内） | unsupported runtime は safe unavailable / 診断 payload は機微フィールドを除外 | 2 passed |

### 6.3 実機 QA（未実施）

実機 QA（F5 / F9 ほか実機必須項目）は未実施。実施したら本節へ追記する。

## 7. 関連文書

- `docs/decisions/ADR-003-rn-full-cutover.md` — gate a〜e / 削除 gate f
- `docs/rn-full-cutover-execution-plan.md` — 実行計画（parity matrix・lane E / G）
- `docs/rn-release-readiness-2026-08-10.md` — リリース準備監査（実機 QA は未実施）
- `docs/rn-export-contract-2026-08-10.md` — Notion / ChatGPT 書き出し契約
- `CLAUDE.md` — 運用ルール（lane・検証マトリクス・STT 保護）
