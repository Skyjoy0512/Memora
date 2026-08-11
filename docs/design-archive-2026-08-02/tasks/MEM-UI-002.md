# MEM-UI-002: PR #151の整理

状態: 完了（2026-08-02、PR #156 merge済み）

## Objective

RNホストがApp Groupなしでもアプリsandboxの共有ストアへ接続できる変更を、mainへ安全に統合できる状態にする。

## Scope

- `origin/main`からストア関連コミットだけを取り込み、PR #151の置換候補を作る
- 4コミット・5ファイルの差分をRNブリッジのfallbackと診断だけに限定
- shared store接続失敗の診断とfallbackをテスト
- `shared-data`、`rn-ios-build`、`expo-check`を通す

## Do not change

- UI再設計
- SpeechAnalyzer実装（PR #152）
- 設計資料の追加改訂

## Acceptance criteria

1. mainとの差分がRNストア接続に限定される
2. App Groupあり／なしの両経路が説明できる
3. 必須CIが成功する
4. PRをDraft解除できる

## Current decision

- `codex/mem-ui-002-store-fallback`は4コミット（`66a167d9`、`1cdf3f95`、`87fa6607`、`f6c4c6ac`）で、QA scriptとTranscript UIを含まず、`origin/main`との差分はstore fallback、bridge診断DTO、Settingsの診断表示に関する同じ5ファイルだけである。
- `f6c4c6ac`でClaude P1/P2を解消した。App Group containerが取得できない場合だけApplication Supportへfallbackし、container取得後のstore open / migration失敗ではsandboxを作らずdefaultsと診断へ戻す。Settingsは`shared-swiftdata`かつエラーなしだけgreenとし、sandbox fallbackはwarningにする。
- `npm ci`、`npm run typecheck`、`npx expo export --platform web`、`git diff --check`は成功した。
- Xcode 26.6の選択とライセンス問題は解消し、`DEVELOPER_DIR`を指定した`swift test --package-path Packages/MemoraSharedData`は45 tests / 9 suitesすべて成功した。
- RN iOS `build-for-testing`は成功した。iOS 26.5 Simulatorへのinstall / launch / Metro接続後にMemora実画面を表示でき、Settingsのdeveloper bridgeは`persistenceScope = shared-swiftdata`、`sharedStoreError = —`で通常App Group経路を確認した。
- MEM-UI-002と非交差だったplayback / summaryのSIGTRAPは、`MEM-BASE-002`でAVAudio WAV fixtureとSwiftData fresh-context assertを修正した。対象2テスト各3回は6 / 6、関連4テスト直列は4 / 4、RN iOS全体は14 / 14成功し、Claude read-only reviewもactionable findingsなしだった。
- `origin/main` `c99f0e4a`へBASE-002→UI-002の順で5コミットを適用したintegration branch `codex/integration-base-002-ui-002`（`e73c33ae`）はcleanで、差分は想定した7ファイルだけだった。元の2 source branchもcleanかつ不変である。
- integration上で`git diff --check`、shared package 45 / 45（9 suites）、typecheck、web export、RN iOS `build-for-testing`、RN iOS 14 / 14（2 suites）が成功した。Simulatorのinstall / launch / Metro接続 / 実画面も成功し、Settingsは`persistenceScope = shared-swiftdata`、`sharedStoreError = —`だった。
- `ExpoModulesProvider`重複警告、Pods checksum drift、SDK build `23F81a` / runtime build `23F73`差はテスト成功後も残るため、MEM-UI-002のmerge blockerではなく別の基盤調査として追跡する。
- BASE-002単独のClaude reviewはno findings、UI-002は以前のClaude P1/P2を解消済みで、最終差分はOpenCode DeepSeek reviewでもP1/P2なしだった。
- MEM-BASE-002 PR [#155](https://github.com/Skyjoy0512/Memora/pull/155)はmerge commit `669ce1f754bd859f5b78287cdb4432fa782a6af2`、MEM-UI-002 PR [#156](https://github.com/Skyjoy0512/Memora/pull/156)はmerge commit `dc62d3fd40a23a777660d384a8238c41eed45666`で`main`へ統合済み。両PRの必須CIは5 / 5成功した。
- Claude P3のdiagnostics static vars非同期問題は、現時点ではmain actor上のstartup書き込みだけであるためMEM-UI-002へ混ぜず、別の基盤タスク候補とする。
- Expo Doctorの16/20は既存mainの基準線問題で、CIの`expo-check`（install / typecheck / web export）には含まれない。`expo-constants` / `expo-linking`、CocoaPods、native config sync、SDK patch mismatchはMEM-UI-002へ混ぜず、別の基盤フォローアップで扱う。

## Merge result

- Luna local: shared package 45 / 45、typecheck、web export、RN iOS build、Simulator 14 / 14 pass
- OpenCode DeepSeek review: P1 / P2なし
- GitHub必須CI: 5 / 5 pass
- PR #156: merge済み
