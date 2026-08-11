# 実装計画

更新日: 2026-08-02
実行者: Codex
状態: 実行可能

## Source of Truth

優先順は次のとおり。

1. `docs/decisions/ADR-001-navigation-architecture.md`
2. `docs/design/information-architecture.md`
3. `docs/design/navigation.md`
4. `docs/design/screens/home.md`
5. 本計画
6. その他の `docs/design/**`（旧案と矛盾する箇所は参考資料）

## 現在地

| 領域 | 現在 | 次の到達点 |
|---|---|---|
| RN基盤 | Expo Router、ネイティブブリッジ、主要画面あり | PRの依存関係を整理して main へ統合 |
| タブ | カスタム `V6FloatingTabBar` | Expo Router `NativeTabs` |
| 作成導線 | FAB と画面内操作 | 中央 FAB の作成メニュー |
| ホーム | ファイル中心の既存画面 | ファイル / プロジェクト切替 + フラット一覧 |
| AI | 独立タブ | 独立タブ + `BottomAccessory` コンポーザー |
| File Detail | Summary / Transcript / Memo | 既存契約を維持して段階的に磨く |
| 品質 | CIは通るがローカルclean installで型解決差あり | clean installとCIの再現性を一致させる |

## 実装原則

- 計画・設計はCodex上のSol、実装はCodex上のGPT-5.6 LunaまたはOpenCodeのDeepSeek、定期レビューはClaudeが担当する。
- 役割とレビュー周期は`docs/agent-operating-model.md`に従う。
- 既存スタックを維持し、画面を一括で書き換えない。
- 1 PR = 1目的。STT、UI、設計、ツールを同じPRへ混ぜない。
- PR #153 の実装は再利用候補として監査し、同じHeroUI移行を作り直さない。
- `File → Meeting` の型・ルート・SwiftData変更は行わない。
- STTコアは明示依頼がない限り変更しない。
- `expo prebuild --clean` は実行しない。

## タスク一覧

| ID | 内容 | 依存 | 規模 |
|---|---|---|---|
| MEM-UI-001 | clean install / typecheck / theme / iOS QA の基準線を復旧 | — | 中 |
| MEM-UI-002 | PR #151を検証・統合可能な状態へ整理 | 001 | 中 |
| MEM-UI-003 | PR #152を#151上で検証・統合可能な状態へ整理 | 002 | 中 |
| MEM-UI-004 | PR #153からUI変更だけを監査・分離 | 003 | 大 |
| MEM-UI-005 | HeroUI Native・Uniwind・トークン基盤を確定 | 004 | 中 |
| MEM-UI-006 | `NativeTabs` へ移行 | 005 | 大 |
| MEM-UI-007 | 中央FABの作成メニューを実装 | 006 | 中 |
| MEM-UI-008 | `NativeTabs.BottomAccessory` の `AIComposer` を実装 | 006 | 大 |
| MEM-UI-009 | ホームヘッダーのファイル / プロジェクト Select | 005, 006 | 中 |
| MEM-UI-010 | ホームのファイル一覧を新仕様へ更新 | 009 | 中 |
| MEM-UI-011 | ホームのプロジェクト表示を実データ契約へ接続 | 009 | 中 |
| MEM-UI-012 | 録音開始フローをFABへ接続 | 007 | 小 |
| MEM-UI-013 | インポートフローをFABへ接続 | 007 | 小 |
| MEM-UI-014 | オンライン会議フローをFABへ接続 | 007 | 中 |
| MEM-UI-015 | グローバル録音・処理状態を固定領域へ接続 | 006, 012 | 中 |
| MEM-UI-016 | File DetailのSummary / Transcript / Memoを新シェルへ適合 | 005 | 大 |
| MEM-UI-017 | Transcriptの進捗・失敗・再試行UXを完成 | 003, 016 | 大 |
| MEM-UI-018 | Tasks / AI / Settings / AuthのUI整合 | 005, 006 | 大 |
| MEM-UI-019 | Dynamic Type対応 | 006-018 | 中 |
| MEM-UI-020 | VoiceOver・フォーカス・44pt監査 | 006-019 | 中 |
| MEM-UI-021 | Light / Dark / Reduce MotionのVisual QA | 006-020 | 中 |
| MEM-UI-022 | Androidホストと検証可否を決定 | 021 | 中 |
| MEM-UI-023 | RNユニットテスト基盤と重要状態テスト | 005 | 中 |
| MEM-UI-024 | SwiftUI/RN並走確認とcutover判断 | 001-023 | 大 |
| MEM-BASE-001 | Expo Doctor既存基準線の依存・native config問題を整理 | — | 中 |
| MEM-BASE-002 | RN iOS AVAudio / SwiftData test fixture安定化 | — | 小 |

## 直近バッチの担当

| タスク | Sol | Primary executor | Secondary / verification | Review gate |
|---|---|---|---|---|
| MEM-UI-002 | scope・受け入れ条件 | OpenCode DeepSeek | Codex側でdiffとCIを再監査（GPT-5.6 LunaはCodexで提供待ち） | — |
| MEM-UI-003 | STT境界・受け入れ条件 | Codex GPT-5.6 Luna | OpenCode DeepSeekがtests/build/logを再検証 | Claude必須 |
| MEM-UI-004 | 分割方針・採否 | OpenCode DeepSeek | Codex GPT-5.6 Lunaが各分割のsmoke test | Claude必須 |

MEM-UI-002〜004が終わった時点でフェーズ0レビューをClaudeへ依頼し、SolがMEM-UI-005以降の順序を再承認する。

## 実行フェーズ

### フェーズ0: 基準線とPR整理（001-004）

依存関係と検証環境を先に正常化する。巨大なPR #153はそのままマージせず、STT・基盤・UI・設計を分離する。

完了条件:

- clean install後の`npm run typecheck`がCIと同じ結果になる
- PR #151 → #152 の依存順が明確
- PR #153から再利用するUIコミットが特定される

### フェーズ1: UI基盤（005）

HeroUI Native、Uniwind、セマンティックトークン、共通状態部品を確定する。

### フェーズ2: アプリシェル（006-008）

NativeTabs、中央FAB、AIComposerを導入する。固定領域の高さは実測し、スクロール末尾を隠さない。

### フェーズ3: 中核導線（009-015）

ホームの再訪体験と、録音・インポート・オンライン会議の作成導線を通す。

### フェーズ4: 内容を読む体験（016-018）

既存機能を壊さずFile Detail、Transcript、Tasks、AI、Settingsを同じUI言語へ揃える。

### フェーズ5: 品質とcutover（019-024）

アクセシビリティ、Visual QA、テスト、並走確認を終えて切替方法を判断する。

## 必須検証

変更範囲に応じて次を実行する。

```bash
cd apps/mobile-expo
npm ci
npm run typecheck
npx expo export --platform web
npm run theme:check      # スクリプト導入後
npm run qa:ios:build     # RNネイティブ変更時
git diff --check
```

`theme:check`が未導入のブランチでは、その事実を失敗理由として記録し、MEM-UI-001または005で追加する。

## 次に実行するタスク

**MEM-UI-003: PR #152を最新main上でSTT目的だけに再構成し、必須検証とClaude reviewへ進める。**

MEM-BASE-002 PR [#155](https://github.com/Skyjoy0512/Memora/pull/155)は`669ce1f754bd859f5b78287cdb4432fa782a6af2`、MEM-UI-002 PR [#156](https://github.com/Skyjoy0512/Memora/pull/156)は`dc62d3fd40a23a777660d384a8238c41eed45666`でmainへmergeされ、両方の必須CIは5 / 5成功した。MEM-UI-002はLuna local検証（shared 45 / 45、typecheck、web export、RN iOS build、Simulator 14 / 14）とOpenCode DeepSeek review（P1 / P2なし）まで完了した。

次はPR #152のSpeechAnalyzer変更を最新mainから独立worktreeへ再構成する。STTコア保護ルールに従い、UI・store fallback・設計変更を混ぜず、tests / build / logsとClaude必須reviewをmerge gateにする。

MEM-UI-001は2026-08-02に完了した。MEM-UI-002のclean branchは4コミット・5ファイルだけで、clean install、型検査、web export、`git diff --check`、`MemoraSharedData` 45 tests / 9 suites、RN iOS `build-for-testing`が成功した。iOS 26.5 Simulatorでinstall / launch / Metro接続後の実画面と、Settingsの通常App Group経路（`shared-swiftdata`、エラーなし）も確認済みで、実装・build・UI smokeは完了している。Claude P1/P2は`f6c4c6ac`で解消し、sandbox fallbackをApp Group container取得不可時だけに制限、store open / migration失敗はdefaultsと診断へ戻し、degraded fallback表示をwarningへ修正した。再度`npm run typecheck`、`npm run qa:ios:build`、`git diff --check`が成功し、実装worktreeはcleanである。

MEM-UI-002と非交差だったplayback / summaryテストは、`MEM-BASE-002`でAVAudio fixtureとSwiftData assertを修正した。対象2件各3回は6 / 6、関連4件直列は4 / 4、RN iOS全体は14 / 14成功し、Claude read-only reviewもactionable findingsなしだった。

`origin/main` `c99f0e4a`へBASE-002→UI-002の5コミットを適用したintegration branch（`e73c33ae`）は想定7ファイルだけでcleanだった。shared package 45 / 45、typecheck、web export、RN iOS build、RN iOS 14 / 14、Simulator install / launch / Metro / 実画面、Settingsの通常App Group経路がすべて成功した。元の2 source branchもcleanかつ不変であり、MEM-UI-002のローカル最終ゲートはpassとする。

BASE-002単独のClaude reviewはno findings、UI-002の以前のClaude P1/P2は解消済みで、最終差分はOpenCode DeepSeek reviewでもP1/P2なしだった。

`ExpoModulesProvider`重複警告、Pods checksum drift、SDK build `23F81a` / runtime build `23F73`差はテスト成功後も残るため、MEM-UI-002のmerge blockerから外し、別の基盤調査で追跡する。

Claude P3のdiagnostics static vars非同期問題は現状のstartup書き込み範囲では別基盤タスク候補とし、MEM-UI-002へ追加しない。

Expo Doctor 16/20の既存基準線問題はMEM-UI-002のスコープ外とし、`MEM-BASE-001`で依存関係、CocoaPods、native config sync、SDK patch mismatchを個別に判定する。

## Progress

- [x] MEM-UI-001 検証基準線の復旧（2026-08-02）
- [x] MEM-UI-002 PR #151の整理（PR #156 merge、必須CI 5 / 5）
- [ ] MEM-UI-003 PR #152の整理
- [ ] MEM-UI-004 PR #153のUI差分分離
- [ ] MEM-BASE-001 Expo Doctor既存基準線の整理
- [x] MEM-BASE-002 RN iOS test fixture安定化（PR #155 merge、必須CI 5 / 5）
