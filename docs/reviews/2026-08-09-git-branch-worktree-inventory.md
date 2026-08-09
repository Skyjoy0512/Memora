# Git Branch / Worktree 棚卸し（2026-08-09）

## 1. 目的とスコープ

- 現在見えている refs だけで全 worktree と主要 local/remote branches を棚卸しし、安全に整理可能な対象を洗い出す。
- 初版（§2〜§10）は **read-only** 調査として作成。後に実行フェーズで `git fetch --prune origin`、`chore/git-inventory-20260809` の origin/main への rebase、**local branch 7 件の安全削除** を実施し、§11 に実行結果として記録した。
- stash・実在 worktree・locked/missing worktree・remote branch は**削除していない**（§11 参照）。
- **第二版（§12）**: 同日 #168〜#174 が origin/main にマージされた後の最新状態を記録（#167 実施後の変化 + 現時点の削除候補）。本版以降の棚卸し結果の正本は §12。

## 2. 前提情報

| 項目 | 値 |
|---|---|
| git version | 2.50.1 (Apple Git-155) |
| remote | `origin https://github.com/Skyjoy0512/Memora.git` |
| origin/HEAD | `refs/remotes/origin/main` |
| origin/main tip | `bd9a2717 feat(rn-ui): migrate status pill to HeroUI (#163)`（fetch --prune / rebase 後） |
| 作業中ブランチ | `chore/git-inventory-20260809`（origin/main に対して ahead 1、working tree clean） |

### 件数サマリ（before → after）

| 対象 | before | after | 変化 |
|---|---|---|---|
| local branches | 104 | 99 | **-7 削除** / +2 新規（test/rn-js-regression-foundation, test/rn-shared-store-cutover） |
| remote origin/* branches（origin/HEAD 除き） | 84 | 85 | -1 prune（feat/mem-rn-found-001-theme-tokens）/+2 新規（上記 test 2 本）。**手動削除なし** |
| PR refs（`refs/remotes/pr/*`） | 5 | 5 | pr/140, 141, 143, 144, 146 変更なし |
| WIP refs（`refs/remotes/wip/*`） | 3 | 3 | wip/clean, wip/v5, wip/vocab 変更なし |
| 登録 worktree | 36 | 38 | +2 新規（Memora-rn-js-regression, Memora-rn-data-cutover-tests） |
| worktree lock | 7 | 7 | 変更なし |
| path 不明（missing）の worktree | 7 | 7 | = lock 7 と同一セット。**削除せず** |
| stash | 22 | 22 | **変更なし（drop/pop 禁止）** |

## 3. 分類基準

| 分類 | 定義 | 判定コマンド |
|---|---|---|
| **A** | origin/main へ内容統合済み（unique commits が 0） | `git branch --merged origin/main` / `git rev-list --count origin/main..<branch>` |
| **B** | unique commits あり。要レビュー（削除候補にしない） | `git branch --no-merged origin/main` |
| **C** | locked / active。worktree に checkout 中、または lock 付き | `git worktree list --porcelain` |
| **D** | path が missing、または prune 候補 | `git worktree prune -n -v` + `ls -d <path>` |
| **E** | checkpoint / archive として保持 | 命名規約（`archive/*`, `wip/*`） |

> 補足: A/B は「content の統合度」、C/D は「worktree の運用状態」なので、1 ブランチが複数分類に該当しうる（例: A+C）。安全削除候補は「A かつ未 checkout（C に非該当）かつ E に非該当」のみ。

## 4. 分類結果

> **注**: §4〜§10 は初版（read-only 調査時点、origin/main tip = `3c12f140`）の記録。実行後（rebase / 削除後）の最新状態は §11 参照。

### A. origin/main へ内容統合済み — 25 local branches

`git rev-list --count origin/main..<branch>` がすべて 0。うち **17 件は worktree に checkout 中（=C 保護）**。

| branch | tip commit | 状態 |
|---|---|---|
| chore/git-inventory-20260809 | `3c12f140` | C（本 worktree） |
| claude/focused-nash-7db2cf | `5619eb11` | C |
| claude/wizardly-shannon-435530 | `ae33500d` | **削除候補**（未 checkout） |
| codex/p0-reference-privacy | `baaf84ed` | C |
| codex/p0-reference-privacy-main | `6310fbfa` | **削除候補**（未 checkout） |
| codex/rn-recovery | `1df9cfdf` | C |
| docs/rn-full-cutover-plan | `3c12f140` | C |
| feat/move-stt-service-shared | `89c5d108` | **削除候補**（未 checkout） |
| feat/rn-summary-bridge | `b39a1aaa` | **削除候補**（未 checkout） |
| feat/transcript-postprocessor | `b6f5a61d` | **削除候補**（未 checkout） |
| fix/api-key-settings-docs | `ae185772` | C+D（path missing, locked） |
| fix/appstore-blocker-auth-paywall | `651a8c12` | C |
| fix/mem-b5-001-settings-placeholders | `08b87ffb` | C |
| fix/rn-ui-polish-abc | `242f5315` | C（2 worktree で checkout） |
| fix/xcodeproj-duplicate-test-reference | `22b70eb5` | **削除候補**（未 checkout, upstream [gone]） |
| main | `1e7173fd` | C（Memora-rn-found-001 で checkout, behind 1） |
| refactor/summary-core-move | `ad3103b0` | **削除候補**（未 checkout） |
| refactor/summary-host-deps-split | `fdc47d7e` | **削除候補**（未 checkout） |
| worktree-agent-a03dd35a02891445e | `9aeb4188` | C+D（path missing, locked） |
| worktree-agent-a04da2776ea13f0c4 | `8c889a38` | C+D |
| worktree-agent-a115d2e704a97ed17 | `242f5315` | C |
| worktree-agent-a530371d958f56ddd | `71659ff3` | C+D |
| worktree-agent-a835b66e37ff02978 | `69317852` | C+D |
| worktree-agent-aa9c68b2 | `f05dd163` | C |
| worktree-agent-ab7cf112c70df46d5 | `7a6ec6b2` | C+D |

### B. unique commits あり（要レビュー）— 79 local branches

`git rev-list --count origin/main..<branch>` が 1 以上。**削除候補にしない**（内容の統合可否は GitHub 上の PR 状態を個別確認すること）。

| ahead | branch | tip commit |
|---|---|---|
| 2 | archive/macbook-worktree-20260802 | `e6f42239`（E） |
| 6 | archive/pr-152-pre-rebase-20260802 | `a7ae109b`（E） |
| 1 | chore/claude-md-parallel-dev | `bf5e7951` |
| 1 | chore/claude-md-post-migration | `39ec7ef1` |
| 1 | chore/qa-fixture-harness | `223a53de` |
| 1 | codex/fix-rn-ios-test-fixtures | `a6b90af7` |
| 5 | codex/integration-base-002-ui-002 | `e73c33ae` |
| 4 | codex/mem-ui-002-store-fallback | `f6c4c6ac` |
| 4 | codex/mem-ui-002-store-fallback-final | `10d9230e` |
| 1 | codex/mem-ui-003-rn-speechanalyzer-hardening | `8507542c` |
| 2 | codex/p0-data-safety | `0ada778a` |
| 15 | codex/pr-b9-audiochunker-streaming | `0e65d0e1` |
| 1 | codex/release-b5-settings-sweep | `cc6fe590` |
| 4 | codex/ui-reproduction-integration | `c7175963`（C+D: **remote に存在せず unique な work が local のみ**） |
| 2 | docs/backend-improvement-plan | `d6260f73` |
| 1 | docs/schema-migration-test-rule | `d5f17979` |
| 1 | docs/ui-ux-redesign | `98897cd8` |
| 1 | feat/12-layout-improvements | `68d9bd10` |
| 6 | feat/apply-transcript-cleaning | `2ab5c3c4` |
| 2 | feat/cl-e3-openai-export-notion-settings | `ee5065f3` |
| 1 | feat/device-import-plaud | `b6eb6ea6` |
| 5 | feat/figma-sync-updates | `fbe1ae0a` |
| 1 | feat/gemini-transcription-provider | `ee78711b` |
| 33 | feat/home-glass-poc | `42e5ffdc` |
| 1 | feat/mem-rn-found-002-ui-provider | `cfcbf079` |
| 1 | feat/mem-rn-prim-001-status-chip | `78f1d786` |
| 1 | feat/mem-ui-003-rn-speechanalyzer | `86d71d7c` |
| 1 | feat/mem-ui-003-speechanalyzer-foundation | `57a89cbd` |
| 1 | feat/mem-ui-003-speechanalyzer-foundation-final | `37e06a86` |
| 1 | feat/move-stt-config-enums-shared | `1c2b9ea8` |
| 1 | feat/move-stt-helpers-shared | `8221bdb0` |
| 1 | feat/move-stt-service-core | `640f85d6` |
| 42 | feat/nothing-glass-redesign | `bcc82f94` |
| 1 | feat/plaud-import-core-salvage | `2afeef1c` |
| 2 | feat/recording-resilience | `602919fd` |
| 2 | feat/recording-segments | `0b591cf4` |
| 5 | feat/rn-askai-bridge | `76dcdcee` |
| 1 | feat/rn-recording-persist-swiftdata | `cdaa99fe` |
| 2 | feat/rn-secure-credentials | `03e6e676` |
| 2 | feat/rn-shared-store-injection | `ced2332e` |
| 10 | feat/rn-speechanalyzer | `d10e99da` |
| 2 | feat/rn-stt-bridge | `2d3c33aa` |
| 33 | feat/rn-ui-improvements | `42e5ffdc`（feat/home-glass-poc と同一 tip） |
| 2 | feat/schema-v5-cleaned-text | `d33c0595` |
| 1 | feat/shared-core-contracts | `46590020` |
| 1 | feat/shared-schema-extraction | `cf498986` |
| 1 | feat/split-stt-support-types | `a53b526c` |
| 2 | feat/stt-checkpoint-resume | `a14d2e9e` |
| 1 | fix/api-key-settings-ui | `0e694f52` |
| 1 | fix/bundle-id-restore | `d83de6a8` |
| 3 | fix/checkpoint-fingerprint-escape | `4a310d95` |
| 1 | fix/empty-store-fallback | `eb96c6f7` |
| 1 | fix/list-display-formatting | `81273331` |
| 1 | fix/mem-base-003-clean-build-input | `8f342ede` |
| 1 | fix/playback-store-unification | `24876bc4` |
| 4 | fix/rn-ondevice-transcription | `184f6dd5` |
| 2 | fix/rn-queued-status | `fcb487e6` |
| 2 | fix/schema-v4-duplicate-checksum | `1b7bf58e` |
| 1 | fix/stt-background-expiration | `be82bc1a` |
| 1 | fix/stt-chunker-streaming | `29e2c438` |
| 2 | fix/stt-streaming-merge | `2b922483` |
| 1 | fix/stt-tail-silence-coverage | `c10356f5` |
| 2 | refactor/askai-core-move | `6ec2d66c` |
| 1 | refactor/generation-flow-sheet | `72673665` |
| 3 | refactor/models-host-dependency-split | `ae190207` |
| 1 | refactor/settings-hierarchy | `2382a6d0` |
| 1 | refactor/stt-deadline-utility | `7d71c9c1` |
| 3 | refactor/stt-diagnostics-inject | `0d2f760a` |
| 4 | refactor/stt-host-contracts-shared | `1f989e29` |
| 1 | refactor/stt-host-seams-capabilities | `fc8d782e` |
| 1 | refactor/stt-host-seams-readonly | `42049868` |
| 2 | refactor/stt-preflight-inject | `18bbc561` |
| 1 | refactor/stt-service-deps-inject | `59c81028` |
| 4 | refactor/stt-service-final-decoupling | `bf5a17a4` |
| 2 | refactor/stt-service-host-factory | `425d2b95` |
| 1 | test/stt-deadline-merge-silence | `189779d5` |
| 2 | test/stt-regression-suite | `b7c4e356` |
| 1 | test/v3-store-fixture | `09b8cbc5` |
| 2 | wip/rn-full-cutover-checkpoint-20260809 | `212329b8`（E+C） |

### C. locked / active（触らない）— worktree に checkout 中の branch 35 件 + detached 1 件

詳細は §5 worktree 一覧を参照。**checkout 中のブランチは削除不可**（`git branch -d` 自体が拒否する）。lock 付き worktree は 7 件。

### D. path missing / prune 候補 — 7 worktree（全件 lock 付き）

| worktree path | branch | lock 理由 | 備考 |
|---|---|---|---|
| `/private/tmp/memora-api-key-docs` | fix/api-key-settings-docs | `initializing` | /tmp 領域のため OS 再起動等で消失の可能性 |
| `/Users/hashimotokenichi/Desktop/Memora/.claude/worktrees/agent-a03dd35a02891445e` | worktree-agent-a03dd35a02891445e | `claude agent ... (pid 29953)` | 別ユーザー `/Users/hashimotokenichi`。現マシンに**未存在** |
| `.../agent-a04da2776ea13f0c4` | worktree-agent-a04da2776ea13f0c4 | 同上 | 同上 |
| `.../agent-a530371d958f56ddd` | worktree-agent-a530371d958f56ddd | 同上 | 同上 |
| `.../agent-a835b66e37ff02978` | worktree-agent-a835b66e37ff02978 | 同上 | 同上 |
| `.../agent-a83fb6df8cc4cf2e5` | **codex/ui-reproduction-integration** | 同上 | **unique work が local のみ（remote 未push）** |
| `.../agent-ab7cf112c70df46d5` | worktree-agent-ab7cf112c70df46d5 | 同上 | 同上 |

- `pid 29953` は現マシンで **未実行**（`ps -p 29953` 該当なし、現ユーザーは `ken`）。`/Users/hashimotokenichi` も存在しない → 旧 MacBook（Mac Studio 移行前）由来の stale lock と推定。
- `git worktree prune -n -v` は**空出力**。lock が付いているため prune 対象になっていない（= 意図的に保護されている状態）。prune 前に unlock 判断が必要。

### E. checkpoint / archive として保持

| branch | ahead | 理由 |
|---|---|---|
| archive/macbook-worktree-20260802 | 2 | Mac Studio 移行前の旧環境スナップショット（`e6f42239`） |
| archive/pr-152-pre-rebase-20260802 | 6 | PR #152 rebase 前の退避（`a7ae109b`） |
| wip/rn-full-cutover-checkpoint-20260809 | 2 | RN 完全移行の checkpoint（`212329b8`）。現在メイン worktree の HEAD |

remote の `refs/remotes/wip/*`（wip/clean, wip/v5, wip/vocab）も WIP 保存として**保持**。

## 5. worktree 一覧（36 件）

| # | path | branch | HEAD | lock | path存在 | ahead |
|---|---|---|---|---|---|---|
| 1 | `/Volumes/DevSSD/Development/Projects/Memora` | wip/rn-full-cutover-checkpoint-20260809 | `212329b8` | - | OK | 2 |
| 2 | `/private/tmp/memora-api-key-docs` | fix/api-key-settings-docs | `ae185772` | **initializing** | **missing** | 0 |
| 3 | `/Users/hashimotokenichi/.../agent-a03dd35a02891445e` | worktree-agent-a03dd35a02891445e | `9aeb4188` | **pid 29953** | **missing** | 0 |
| 4 | `/Users/hashimotokenichi/.../agent-a04da2776ea13f0c4` | worktree-agent-a04da2776ea13f0c4 | `8c889a38` | **pid 29953** | **missing** | 0 |
| 5 | `/Users/hashimotokenichi/.../agent-a530371d958f56ddd` | worktree-agent-a530371d958f56ddd | `71659ff3` | **pid 29953** | **missing** | 0 |
| 6 | `/Users/hashimotokenichi/.../agent-a835b66e37ff02978` | worktree-agent-a835b66e37ff02978 | `69317852` | **pid 29953** | **missing** | 0 |
| 7 | `/Users/hashimotokenichi/.../agent-a83fb6df8cc4cf2e5` | codex/ui-reproduction-integration | `c7175963` | **pid 29953** | **missing** | 4 |
| 8 | `/Users/hashimotokenichi/.../agent-ab7cf112c70df46d5` | worktree-agent-ab7cf112c70df46d5 | `7a6ec6b2` | **pid 29953** | **missing** | 0 |
| 9 | `/Volumes/DevSSD/Development/Projects/Memora-api-key-settings-ui` | fix/api-key-settings-ui | `0e694f52` | - | OK | 1 |
| 10 | `.../Memora-appstore-blocker` | fix/appstore-blocker-auth-paywall | `651a8c12` | - | OK | 0 |
| 11 | `.../Memora-device-import-plaud` | feat/device-import-plaud | `b6eb6ea6` | - | OK | 1 |
| 12 | `.../Memora-git-inventory` | chore/git-inventory-20260809 | `3c12f140` | - | OK | 0 |
| 13 | `.../Memora-glass` | feat/home-glass-poc | `42e5ffdc` | - | OK | 33 |
| 14 | `.../Memora-integration-base-002-ui-002` | codex/integration-base-002-ui-002 | `e73c33ae` | - | OK | 5 |
| 15 | `.../Memora-mem-b5-001` | fix/mem-b5-001-settings-placeholders | `08b87ffb` | - | OK | 0 |
| 16 | `.../Memora-mem-ui-002` | fix/rn-ondevice-transcription | `184f6dd5` | - | OK | 4 |
| 17 | `.../Memora-mem-ui-002-clean` | codex/mem-ui-002-store-fallback | `f6c4c6ac` | - | OK | 4 |
| 18 | `.../Memora-mem-ui-002-final` | codex/mem-ui-002-store-fallback-final | `10d9230e` | - | OK | 4 |
| 19 | `.../Memora-p0-data-safety` | codex/p0-data-safety | `0ada778a` | - | OK | 2 |
| 20 | `.../Memora-p0-reference-privacy` | codex/p0-reference-privacy | `baaf84ed` | - | OK | 0 |
| 21 | `.../Memora-rn-cutover-plan` | docs/rn-full-cutover-plan | `3c12f140` | - | OK | 0 |
| 22 | `.../Memora-rn-found-001` | **main** | `1e7173fd` | - | OK | 0 |
| 23 | `.../Memora-rn-found-002` | feat/mem-rn-found-002-ui-provider | `cfcbf079` | - | OK | 1 |
| 24 | `.../Memora-rn-ios-test-fixtures` | codex/fix-rn-ios-test-fixtures | `a6b90af7` | - | OK | 1 |
| 25 | `.../Memora-rn-prim-001` | feat/mem-rn-prim-001-status-chip | `78f1d786` | - | OK | 1 |
| 26 | `.../Memora-rn-recovery` | codex/rn-recovery | `1df9cfdf` | - | OK | 0 |
| 27 | `.../Memora-rn-ui-polish` | fix/rn-ui-polish-abc | `242f5315` | - | OK | 0 |
| 28 | `/Volumes/DevSSD/Development/Projects/Memora/.claude/worktrees/agent-a115d2e704a97ed17` | worktree-agent-a115d2e704a97ed17 | `242f5315` | - | OK | 0 |
| 29 | `.../.claude/worktrees/agent-aa9c68b2` | worktree-agent-aa9c68b2 | `f05dd163` | - | OK | 0 |
| 30 | `.../.claude/worktrees/focused-nash-7db2cf` | claude/focused-nash-7db2cf | `5619eb11` | - | OK | 0 |
| 31 | `.../.claude/worktrees/mem-base-003` | fix/mem-base-003-clean-build-input | `8f342ede` | - | OK | 1 |
| 32 | `.../.claude/worktrees/mem-ui-003-foundation` | feat/mem-ui-003-speechanalyzer-foundation | `57a89cbd` | - | OK | 1 |
| 33 | `.../.claude/worktrees/mem-ui-003-foundation-final` | feat/mem-ui-003-speechanalyzer-foundation-final | `37e06a86` | - | OK | 1 |
| 34 | `.../.claude/worktrees/mem-ui-003-rn-speechanalyzer` | feat/mem-ui-003-rn-speechanalyzer | `86d71d7c` | - | OK | 1 |
| 35 | `.../.claude/worktrees/mem-ui-003-rn-speechanalyzer-hardening` | codex/mem-ui-003-rn-speechanalyzer-hardening | `8507542c` | - | OK | 1 |
| 36 | `.../.claude/worktrees/wizardly-shannon-435530` | **（detached）** | `ae33500d` | - | OK | 0 |

> 注: fix/rn-ui-polish-abc は #27 と #28 の 2 worktree で checkout 中。worktree メタデータは `/Volumes/DevSSD/Development/Projects/Memora/.git/worktrees/` に集約。

## 6. stash — 22 件（保護方針）

- `git stash list` で 22 件確認（`stash@{0}`〜`stash@{21}`）。最も新しい `stash@{0}` は `feat/rn-ui-improvements` 上の「中断した構造系4ファイル + 未コミット変更（設計切り出しのため退避）」。
- 対象ブランチの大半は既に存在しない/リモートに無いケースもあり、**stash が唯一のコピーの可能性が高い**。
- **方針: drop 禁止・pop 禁止**。整理時も触らない。各 stash の保持判断は別タスク（`git stash show -p` での内容レビュー）とする。

## 7. 安全な削除候補（本調査で断定できるもののみ）

**local branch 8 件** — すべて A（unique commits 0）かつ未 checkout かつ archive/wip でないため、`git branch -d` が失敗しないことが git により保証される。

```
claude/wizardly-shannon-435530
codex/p0-reference-privacy-main
feat/move-stt-service-shared
feat/rn-summary-bridge
feat/transcript-postprocessor
fix/xcodeproj-duplicate-test-reference
refactor/summary-core-move
refactor/summary-host-deps-split
```

- 判定根拠: `git branch --merged origin/main` に含まれる / `git rev-list --count origin/main..<branch>` = 0 / worktree に checkout されていない。
- これは「削除しても失うものが無い」ことの保証であり、「削除すべき」の推奨ではない。削除実行は §8 の Stage 1 で、オペレータの確認ゲートを経て行う。
- **実行結果**: このうち **7 件を削除**（§11 参照）。**`feat/transcript-postprocessor` は upstream に対して ahead 1, behind 4 の乖離があり削除条件「upstream ahead = 0」を満たさないため保持**（曖昧さは保持方針に従う）。

**remote branch は削除候補にしない**（要 PR 確認、§8 Stage 3 参照）。

## 8. cleanup 3 段階コマンド案（実行案であり、本調査では未実行）

各段階の前に前段の結果確認とオペレータ承認を必ず挟む。各段階は成功した段階までで停止可。

### Stage 0 — 再確認（read-only）
```bash
git status
git worktree list
git worktree prune -n -v
git branch --merged origin/main
```
**ゲート**: 本ドキュメント §4 の分類と整合すること。ずれがあれば中止。

### Stage 1 — 安全な local branch 削除（8 件）
```bash
git branch -d \
  claude/wizardly-shannon-435530 \
  codex/p0-reference-privacy-main \
  feat/move-stt-service-shared \
  feat/rn-summary-bridge \
  feat/transcript-postprocessor \
  fix/xcodeproj-duplicate-test-reference \
  refactor/summary-core-move \
  refactor/summary-host-deps-split
```
- `-d`（--delete）はマージ済み以外を削除しないため安全。
**ゲート**: 全 8 件が `Deleted branch ...` を返し、`error: The branch ... is not fully merged` が 1 件も無いこと。

### Stage 2 — path missing の worktree 7 件の整理（lock 解除 → prune）
```bash
# 2-a) 事前確認（lock 理由・該当 pid・他ユーザー領域であることを再確認）
cat "$(git rev-parse --git-common-dir)/worktrees/memora-api-key-docs/locked"
cat "$(git rev-parse --git-common-dir)/worktrees/agent-a03dd35a02891445e/locked"
# ... 同様に agent-a04da2776ea13f0c4 / a530371d958f56ddd / a835b66e37ff02978 / a83fb6df8cc4cf2e5 / ab7cf112c70df46d5

# 2-b) unlock（branch は削除しない。metadata だけ整理）
git worktree unlock /private/tmp/memora-api-key-docs
git worktree unlock /Users/hashimotokenichi/Desktop/Memora/.claude/worktrees/agent-a03dd35a02891445e
# ... 残り 5 件も同様に unlock

# 2-c) dry-run で対象確認 → 本番
git worktree prune -n -v
git worktree prune
```
- `/Users/hashimotokenichi/...` は現マシンに存在しない別ユーザー領域。**移行元 MacBook の同一リポジトリで worktree 登録されていたものが残った可能性が高く、削除可否はオーナー確認が必須**。
- `codex/ui-reproduction-integration`（#7）は unique work が local にしか無いため、**branch は絶対に削除しない**（worktree metadata だけの整理）。
**ゲート**: `git worktree list` から 7 件が消え、対応 branch が**残存**していること。

### Stage 3 — remote branch 整理（要 GitHub 上での PR 状態確認）
origin/main に統合済みの origin/* branch 13 件は候補だが、open PR の自動クローズを避けるため**削除しない**:
```
git rev-list --count origin/main..origin/<branch>   # = 0 のものだけ対象
```
対象 13 件: `codex/feat-posthoc-diarization`, `codex/feat-summarization-provider-select`, `codex/feat-transcript-autoscroll`, `codex/feat-transcript-timed-segments`, `codex/feat-transcript-ui-timed-scroll`, `codex/phaseb-b4-tail-silence`, `codex/phaseb-b8-checkpoint-resume`, `codex/phasec-z1-gemini-fix`, `codex/test-stt-core`, `feat/perf-optimization`, `feat/rn-summary-bridge`, `refactor/summary-core-move`, `refactor/summary-host-deps-split`
```bash
# 各ブランチの PR が Merged/Closed であることを gh 等で確認してから
gh pr list --state all --head <branch>        # 例
git push origin --delete <branch>             # PR クローズ確認後にのみ
```
- `refs/remotes/pr/*`（GitHub 管理）、`refs/remotes/wip/*`（WIP 保存）は**削除対象外**。
**ゲート**: 削除する各 PR が GitHub 上で merged/closed 済みであることの目視確認。`git fetch -p` は使わない（remote-tracking を書き換えるため、本棚卸しの制約を継続）。

### 禁止・保留事項
- stash 22 件: drop/pop 禁止。
- A だが C 保護中の 17 件・B 79 件・E 3 件の local branch: 削除しない。
- B のうち `feat/home-glass-poc` = `feat/rn-ui-improvements`（同一 tip `42e5ffdc`, ahead 33）、`fix/rn-ui-polish-abc` = `worktree-agent-a115d2e704a97ed17`（同一 tip `242f5315`）は重複 work。統合可否はレビューに委ねる。

## 9. 実行した検証コマンド（read-only）

| コマンド | 結果 |
|---|---|
| `git status` | clean / `chore/git-inventory-20260809` は origin/main と同期 |
| `git branch -a -v --no-abbrev` | local 104 / origin 84 を確認 |
| `git worktree list --porcelain` | 36 worktree、lock 7 件を確認 |
| `git worktree prune -n -v` | **出力なし**（prune 対象なし） |
| `git branch --merged origin/main` | 25 件 |
| `git branch --no-merged origin/main` | 79 件 |
| `git rev-list --count origin/main..<branch>` | 全 local/remote branch の ahead 数 |
| `git for-each-ref ... %(upstream:track)` | ahead/behind・[gone] を確認 |
| `ls -d <worktree-path>` | 7 件が missing と判明 |
| `cat .../worktrees/<name>/locked` | lock 理由を確認 |
| `ps -p 29953` | pid 未実行（stale lock と推定） |
| `git stash list` | 22 件 |

## 10. 未確認事項

- 各 B ブランチの GitHub 上での PR 状態（merged/open/closed）。
- `/Users/hashimotokenichi/...` の worktree が「旧 MacBook 由来」であることの確定（オーナー確認が必要）。
- stash 22 件それぞれの内容（`git stash show` 未実施）。

## 11. クリーンアップ実行結果（2026-08-09）

### 11.1 実施した操作

1. `git fetch --prune origin` → `origin/feat/mem-rn-found-001-theme-tokens` の stale tracking ref を削除（remote branch 自体は変更なし）。
2. `chore/git-inventory-20260809` を最新 origin/main（`bd9a2717`, PR #163 マージ済み）へ **rebase 成功**。
3. 再監査（§2 の before → after）。origin/main 移動後も統合済み未 checkout の候補は §7 の 8 件のみであることを確認。

### 11.2 削除した local branch（7 件）

`git branch -d <明示名>` で 1 件ずつ削除。全件 `Deleted branch` を返し、`not fully merged` エラーは 0 件。

| branch | 削除時 tip | 根拠 |
|---|---|---|
| claude/wizardly-shannon-435530 | `ae33500d` | unique 0 / 未 checkout（wizardly-shannon worktree は detached HEAD）/ upstream なし |
| codex/p0-reference-privacy-main | `6310fbfa` | unique 0 / 未 checkout / upstream [gone] |
| feat/move-stt-service-shared | `89c5d108` | unique 0 / 未 checkout / upstream なし |
| feat/rn-summary-bridge | `b39a1aaa` | unique 0 / 未 checkout / upstream equal |
| fix/xcodeproj-duplicate-test-reference | `22b70eb5` | unique 0 / 未 checkout / upstream [gone] |
| refactor/summary-core-move | `ad3103b0` | unique 0 / 未 checkout / upstream equal |
| refactor/summary-host-deps-split | `fdc47d7e` | unique 0 / 未 checkout / upstream equal |

### 11.3 保持した対象と理由

| 対象 | 件数 | 理由 |
|---|---|---|
| feat/transcript-postprocessor | 1 | unique 0 だが upstream に対して ahead 1, behind 4。削除条件「upstream ahead = 0」を満たさない（曖昧さがあるため保持） |
| 統合済み local branch（C 保護） | 17 | worktree に checkout 中（worktree-agent-* 7 件含む） |
| B 分類（unique commits あり） | 76 | 内容の統合可否は PR 状態を個別確認が必要 |
| E 分類（archive / checkpoint） | 3 | `archive/macbook-worktree-20260802`, `archive/pr-152-pre-rebase-20260802`, `wip/rn-full-cutover-checkpoint-20260809` |
| stash | 22 | drop/pop 禁止（唯一のコピーの可能性） |
| locked / missing worktree | 7 | 削除せず。`git worktree prune -n -v` は**空出力**（lock により prune 対象外） |
| 実在 worktree ディレクトリ | 38 | 削除しない |
| remote branch（origin/*, pr/*, wip/*） | - | 削除しない |

### 11.4 GitHub 上の PR 状態確認

| PR | state | head branch | 備考 |
|---|---|---|---|
| #164 | OPEN | `docs/rn-full-cutover-plan` | worktree に checkout 中、未削除 |
| #165 | OPEN | `test/rn-js-regression-foundation` | worktree に checkout 中、未削除 |
| #166 | OPEN | `test/rn-shared-store-cutover` | worktree に checkout 中、未削除 |

> **追記（第二版）**: #164/#165/#166 はいずれも同日中に **MERGED** に移行（#164 は #167 時点で閉じられていた open PR の続き含む）。最終状態は §12.3 参照。

### 11.5 checkpoint 212329b8 の保全状態

- `212329b8 chore: checkpoint RN cutover work before lane split` は**commit として実在**。
- `wip/rn-full-cutover-checkpoint-20260809`（E+C）が保持し、メイン worktree `/Volumes/DevSSD/Development/Projects/Memora` の HEAD。削除対象外。

### 11.6 検証

| コマンド | 結果 |
|---|---|
| `git worktree prune -n -v` | 空出力（prune 対象なし、7 lock は保護） |
| `git diff --check` | pass |
| 削除時 `git branch -d` 各 1 件 | 全 7 件成功、`not fully merged` 0 件 |

### 11.7 未実施 / 保留

- remote branch の push --delete は実施しない（§8 Stage 3 は保留。PR #164/#165/#166 は OPEN のため対象外）。
- locked/missing worktree 7 件の unlock・prune はオーナー確認後（別タスク）。
- stash 22 件の内容レビューは別タスク。

## 12. 第二版（2026-08-09 夜 / #168〜#174 マージ後、origin/main = cd6a3583）

> 本節は #167（§1〜§11）実施後に #168〜#174 が origin/main へマージされた後の再棚卸し。`chore/git-inventory-20260809b`（本 worktree）上で read-only 調査のみ実施（削除・push --delete は一切しない）。

### 12.1 前提情報（本版時点）

| 項目 | 値 |
|---|---|
| origin/main tip | `042f59bd feat(rn-infra): Node 22/npm 10のローカルピン（.node-version + engines）を復元 (#175)`（本調査の時点では `cd6a3583`=#174。調査後に #175 がマージされた） |
| 作業中ブランチ | `chore/git-inventory-20260809b`（本 worktree。origin/main へ rebase 済み） |
| 実行環境 | 本 worktree 内のみ。docs 以外の変更なし |

### 12.2 件数サマリ（#167 時点 → 本版）

| 対象 | #167 後 | 本版 | 変化 |
|---|---|---|---|
| local branches | 99 | 108 | **+9**（#168〜#174 の head 8 + chore/git-inventory-20260809b） |
| remote origin/* branches（origin/HEAD 除き） | 85 | 95 | +10（うち新規確認 8 本:#168〜#174 の head 7 + feat/rn-checkpoint-next-slice。残り 2 は計数方法の差の可能性あり） |
| PR refs（`refs/remotes/pr/*`） | 5 | 5 | pr/140, 141, 143, 144, 146 不変 |
| WIP refs（`refs/remotes/wip/*`） | 3 | 3 | wip/clean, wip/v5, wip/vocab 不変 |
| 登録 worktree | 38 | 47 | **+9** |
| worktree lock | 7 | 7 | 不変 |
| path 不明（missing）の worktree | 7 | 7 | 不変（= lock 7 件と同一セット） |
| stash | 22 | 22 | 不変（drop/pop 禁止） |
| tags | - | 0 | なし |

### 12.3 GitHub PR 状態（#167〜#174 の進行）

| PR | state | head branch | 備考 |
|---|---|---|---|
| #168 | **MERGED** | `feat/rn-ui-checkpoint-parity` | checkpoint parity slice 抽出 |
| #169 | **MERGED** | `chore/remove-root-build-artifacts` | ルート直下の残存ビルド成果物削除 |
| #170 | **MERGED** | `fix/rn-release-route-gates` | リリースゲート導入 |
| #171 | **MERGED** | `docs/rn-identity-store-policy` | ADR-004 方針確定 |
| #172 | **MERGED** | `feat/rn-adr004-identity` | RN 本番 bundle ID / Keychain 統一 |
| #173 | **MERGED** | `feat/rn-adr004-store-migration` | 共有 SwiftData ストア解決を集約 |
| #174 | **MERGED** | `fix/rn-release-gate-2` | gate c 仕上げ（origin/main 先端） |
| #175 | **MERGED**（調査時点は OPEN） | `feat/rn-checkpoint-next-slice` | Node 22 / npm 10 のローカルピン。調査後にマージされ origin/main 先端となった（`042f59bd`） |

- #167 時点で OPEN だった #164/#165/#166 はすべて **MERGED** 済み。

### 12.4 新規 worktree（+9 件、すべて /Volumes/DevSSD 配下・lock なし）

| path | branch | HEAD | ahead | 由来 PR |
|---|---|---|---|---|
| `.../Memora-git-inventory2` | chore/git-inventory-20260809b | `cd6a3583` | 0 | 本棚卸し第二版 |
| `.../Memora-git-root-hygiene` | chore/remove-root-build-artifacts | `7287e745` | 1 | #169 |
| `.../Memora-rn-checkpoint-next` | feat/rn-checkpoint-next-slice | `a476e7b8` | 1 | #175 |
| `.../Memora-rn-identity` | feat/rn-adr004-identity | `e5287371` | 1 | #172 |
| `.../Memora-rn-identity-store` | docs/rn-identity-store-policy | `9398e440` | 1 | #171 |
| `.../Memora-rn-release-gate` | fix/rn-release-route-gates | `700769a5` | 1 | #170 |
| `.../Memora-rn-release-gate2` | fix/rn-release-gate-2 | `8014c0af` | 1 | #174 |
| `.../Memora-rn-store-migration` | feat/rn-adr004-store-migration | `0153b501` | 1 | #173 |
| `.../Memora-rn-ui-checkpoint-parity` | feat/rn-ui-checkpoint-parity | `421d9e31` | 1 | #168 |

> 全 9 件が実在ディレクトリ・実在 worktree。branch は削除対象外（checkout 中 = C 保護）。

### 12.5 分類結果（本版）

**A. origin/main へ内容統合済み（unique commits 0）— 16 local branches（main 除く）**

`git rev-list --count origin/main..<branch>` = 0。前回の 17 件から `feat/rn-checkpoint-next-slice` が #175 の commit（`a476e7b8`）追加で **B に移行**したため 16 件。

| branch | 状態 |
|---|---|
| chore/git-inventory-20260809b | C（本 worktree） |
| claude/focused-nash-7db2cf | C |
| codex/p0-reference-privacy | C |
| codex/rn-recovery | C |
| feat/transcript-postprocessor | **未 checkout**（唯一の A 非保護） |
| fix/api-key-settings-docs | C+D（path missing, locked） |
| fix/appstore-blocker-auth-paywall | C |
| fix/mem-b5-001-settings-placeholders | C |
| fix/rn-ui-polish-abc | C（2 worktree） |
| worktree-agent-a03dd35a02891445e | C+D（path missing, locked） |
| worktree-agent-a04da2776ea13f0c4 | C+D |
| worktree-agent-a115d2e704a97ed17 | C |
| worktree-agent-a530371d958f56ddd | C+D |
| worktree-agent-a835b66e37ff02978 | C+D |
| worktree-agent-aa9c68b2 | C |
| worktree-agent-ab7cf112c70df46d5 | C+D |

**B. unique commits あり（要レビュー）— 91 local branches（main 除く）**

non-main local branches 計 107 件のうち A 16 件を除く 91 件（`git rev-list --count origin/main..<branch>` ≥ 1 で実測）。#168〜#174 の head 7 件、`feat/rn-checkpoint-next-slice`（ahead 1, #175）、その他既存 B が該当。詳細は ahead 一覧参照（§12.7 に主要行のみ掲載）。**削除候補にしない**。

**C. locked / active — 7 worktree（全件 path missing）**

§12.6 参照。lock 理由は `initializing` 1 件 + `claude agent ... (pid 29953)` 6 件。`pid 29953` は現マシンで未実行、`/Users/hashimotokenichi` も未存在（§5 と同じ判定）。

**D. path missing / prune 候補 — 7 worktree（全件 lock 付き）**

§5 の #2〜#8 と同じ 7 件。`git worktree prune -n -v` は**空出力**（lock のため prune 対象外）。前回からの変化なし。

**E. checkpoint / archive として保持**

| branch | ahead | 理由 |
|---|---|---|
| archive/macbook-worktree-20260802 | 2 | 旧環境スナップショット |
| archive/pr-152-pre-rebase-20260802 | 6 | PR #152 rebase 前退避 |
| wip/rn-full-cutover-checkpoint-20260809 | 2 | RN 完全移行 checkpoint（メイン worktree HEAD） |

remote の `refs/remotes/wip/*`（wip/clean, wip/v5, wip/vocab）も WIP 保存として保持。

### 12.6 削除候補（証拠付き・実行しない）

**① A だが未 checkout の local branch — 1 件**

| branch | 証拠 | 対応 |
|---|---|---|
| `feat/transcript-postprocessor` | `git branch --merged origin/main` に含まれる / ahead 0 / 全 worktree で未 checkout。ただし upstream `origin/feat/transcript-postprocessor` は [ahead 1, behind 4] で乖離あり | **保持継続**（#167 と同じ。upstream の乖離はオーナー判断が必要） |

**② stale / locked な agent worktree — 7 件（branch は削除しない）**

| path | branch | lock 理由 | 証拠 |
|---|---|---|---|
| `/private/tmp/memora-api-key-docs` | fix/api-key-settings-docs | `initializing` | `/private/tmp/memora-api-key-docs` は**未存在** |
| `/Users/hashimotokenichi/Desktop/Memora/.claude/worktrees/agent-a03dd35a02891445e` | worktree-agent-a03dd35a02891445e | `pid 29953` | `/Users/hashimotokenichi` は**未存在**。現ユーザーは `ken` |
| `.../agent-a04da2776ea13f0c4` | worktree-agent-a04da2776ea13f0c4 | 同上 | 同上 |
| `.../agent-a530371d958f56ddd` | worktree-agent-a530371d958f56ddd | 同上 | 同上 |
| `.../agent-a835b66e37ff02978` | worktree-agent-a835b66e37ff02978 | 同上 | 同上 |
| `.../agent-a83fb6df8cc4cf2e5` | **codex/ui-reproduction-integration** | 同上 | 同上。unique work が local のみ（remote 未push）のため **branch は絶対に削除しない** |
| `.../agent-ab7cf112c70df46d5` | worktree-agent-ab7cf112c70df46d5 | 同上 | 同上 |

**③ 未使用 remote ref（`refs/remotes/pr/*`）— 5 件**

| ref | 対応 PR | PR 状態 |
|---|---|---|
| pr/140 | #140 | MERGED |
| pr/141 | #141 | MERGED |
| pr/143 | #143 | MERGED |
| pr/144 | #144 | MERGED |
| pr/146 | #146 | MERGED |

- 対応 PR がすべて merged/closed 済みのため使用されていない ref だが、GitHub 管理領域のため**削除しない**。

**④ origin/* 統合済み remote branch — 13 件（前回不変）**

§8 Stage 3 の 13 件（codex/feat-posthoc-diarization 等）は変わらず `--merged origin/main` のまま。**削除しない**（§8 のゲートに従う）。

### 12.7 ahead 一覧（B 分類の主要行のみ）

```
42 feat/nothing-glass-redesign
33 feat/rn-ui-improvements / feat/home-glass-poc
15 codex/pr-b9-audiochunker-streaming
10 feat/rn-speechanalyzer
 6 feat/apply-transcript-cleaning / archive/pr-152-pre-rebase-20260802
 5 feat/rn-askai-bridge / feat/figma-sync-updates / codex/integration-base-002-ui-002
 4 refactor/stt-service-final-decoupling / fix/rn-ondevice-transcription ほか
 ...
 1 feat/rn-checkpoint-next-slice（#175 OPEN）/ #168〜#174 の head 各 1 件 ほか
 0 （A 分類 16 件）
```

### 12.8 検証

| コマンド | 結果 |
|---|---|
| `git fetch origin --prune` | 正常終了（stale tracking ref の削除は発生） |
| `git worktree prune -n -v` | 空出力（prune 対象なし、7 lock は保護） |
| `git branch --merged origin/main` | 16 件（main 除く） |
| `git diff --check` | pass |
| 変更ファイル | `docs/**` のみ |

### 12.9 未確認事項

- remote origin/* の +10 のうち明示的に特定できた新規は 8 本。残り 2 本の差分は計数方法の差の可能性（次回以降で `git for-each-ref` ベースの一覧で突合する）。
- 各 B ブランチの GitHub 上での PR 状態（#175 以外は open PR なし）。
- `/Users/hashimotokenichi/...` worktree が旧 MacBook 由来であることの確定（オーナー確認が必須）。
- stash 22 件それぞれの内容（`git stash show` 未実施）。

## 13. Git 整理実行（2026-08-09、ユーザー承認済み）

> ユーザー承認済みの対象のみを §12 で確定した証拠に基づき 1 件ずつ実行。本 worktree（`chore/git-cleanup-20260809`、origin/main = `ddaf7753` 基準）から git コマンドのみで実施し、外部ディレクトリへの操作は行っていない。

### 13.1 削除した対象

**統合済み local branch（`git branch -d`、計 6 件）**

| branch | 削除時 tip | 証拠 |
|---|---|---|
| feat/transcript-postprocessor | `b6f5a61d` | `git branch --merged origin/main` に含まれる / ahead 0 / 全 worktree 未 checkout。upstream が remote のみに残っていたため `-d` が拒否したが、remote branch 削除後に再実行し成功 |
| worktree-agent-a03dd35a02891445e | `9aeb4188` | 同上。worktree prune 後（未 checkout 化）に `-d` 成功 |
| worktree-agent-a04da2776ea13f0c4 | `8c889a38` | 同上 |
| worktree-agent-a530371d958f56ddd | `71659ff3` | 同上 |
| worktree-agent-a835b66e37ff02978 | `69317852` | 同上 |
| worktree-agent-ab7cf112c70df46d5 | `7a6ec6b2` | 同上 |

**missing/locked worktree の登録解除（7 件）**

事前に `ls -d` で全パス未存在、`locked` ファイル（`initializing` 1 件 / `claude agent ... (pid 29953)` 6 件）、`ps -p 29953` 未実行を確認。`git worktree unlock` → `git worktree prune -v` で登録解除。

| path | branch | lock 理由 |
|---|---|---|
| /private/tmp/memora-api-key-docs | fix/api-key-settings-docs | initializing |
| /Users/hashimotokenichi/Desktop/Memora/.claude/worktrees/agent-a03dd35a02891445e | worktree-agent-a03dd35a02891445e | pid 29953 |
| .../agent-a04da2776ea13f0c4 | worktree-agent-a04da2776ea13f0c4 | pid 29953 |
| .../agent-a530371d958f56ddd | worktree-agent-a530371d958f56ddd | pid 29953 |
| .../agent-a835b66e37ff02978 | worktree-agent-a835b66e37ff02978 | pid 29953 |
| .../agent-a83fb6df8cc4cf2e5 | **codex/ui-reproduction-integration** | pid 29953 |
| .../agent-ab7cf112c70df46d5 | worktree-agent-ab7cf112c70df46d5 | pid 29953 |

**stale PR ref（`git update-ref -d`、計 5 件）**

`refs/remotes/pr/140`, `pr/141`, `pr/143`, `pr/144`, `pr/146`（対応 PR はすべて MERGED 済み。§12.6③）。

**統合済み remote branch（`git push origin --delete`、計 14 件）**

13 件（§12.6④）は事前に `git rev-list --count origin/main..origin/<branch>` = 0（ahead 0）を全件確認。OPEN PR の head は対象に含まれないことを `gh pr list --state open` で確認。

```
codex/feat-posthoc-diarization
codex/feat-summarization-provider-select
codex/feat-transcript-autoscroll
codex/feat-transcript-timed-segments
codex/feat-transcript-ui-timed-scroll
codex/phaseb-b4-tail-silence
codex/phaseb-b8-checkpoint-resume
codex/phasec-z1-gemini-fix
codex/test-stt-core
feat/perf-optimization
feat/rn-summary-bridge          （PR #116 MERGED）
refactor/summary-core-move      （PR #114 MERGED）
refactor/summary-host-deps-split（PR #113 MERGED）
feat/transcript-postprocessor   （追加承認分。PR #140 MERGED、auto-PR 成果物）
```

### 13.2 保持した対象

| 対象 | 件数 | 状態 |
|---|---|---|
| stash | 22 | 内容未レビューのため drop/pop せず保持 |
| refs/remotes/wip/*（clean, v5, vocab） | 3 | WIP 保存として保持 |
| archive/*（macbook-worktree-20260802, pr-152-pre-rebase-20260802） | 2 | checkpoint/archive として保持 |
| wip/rn-full-cutover-checkpoint-20260809 | 1 | RN cutover checkpoint（メイン worktree HEAD）保持 |
| codex/ui-reproduction-integration | 1 | unique local work が残るため branch 削除せず（worktree metadata のみ整理） |
| fix/api-key-settings-docs | 1 | 統合済みだが削除対象外（worktree-agent-* ではないため保持） |
| worktree-agent-a115d2e704a97ed17 / worktree-agent-aa9c68b2 | 2 | 実在 worktree に checkout 中のため保持 |
| その他 B 分類（unique commits あり）の local branch | 多数 | 削除しない |
| 実在 worktree ディレクトリ（DevSSD 配下 47 件） | 47 | 削除しない |

### 13.3 検証

| コマンド | 結果 |
|---|---|
| `git branch -d` 各 1 件 | 計 6 件成功、`not fully merged` 0 件（transcript-postprocessor は upstream ref 残存で一度拒否→remote 削除後に成功） |
| `git worktree unlock` + `git worktree prune -v` | 7 件が `Removing worktrees/...` で登録解除 |
| `git update-ref -d` pr ref 5 件 | 成功、`refs/remotes/pr/*` 0 件 |
| `git push origin --delete` 14 件 | 全件 `- [deleted]` を確認 |
| 削除後残存確認 | 削除対象の local/remote branch・pr ref が 0 件（`git branch --merged origin/main` / `git for-each-ref` で確認） |
| 保持対象確認 | stash 22 / wip 3 / archive 2 / checkpoint 1 / ui-reproduction-integration 残存 |
| `git diff --check` | pass |
| 変更ファイル | `docs/**` のみ |

### 13.4 未実施 / 保留

- stash 22 件の内容レビュー（別タスク）。
- B 分類の未統合 local branch の整理判断（PR 状態個別確認が必要）。
- 実在 worktree の整理・worktree-agent-a115d2e704a97ed17 / aa9c68b2 の branch 削除（checkout 中のため対象外）。

## 14. Git 整理第2弾（2026-08-10、ユーザー承認済み）

> ユーザー承認済みの対象のみを 1 件ずつ事前検証して実行。本 worktree（`chore/git-cleanup-20260810`、origin/main = `657a73de` 基準）から git/gh コマンドのみで実施し、外部ディレクトリ・`rm -rf`・ワイルドカード一括削除は使用していない。

### 14.1 削除した対象

**統合済み remote branch（`git push origin --delete`、計 11 件）**

全 11 件について、対応 PR が `state=MERGED` であること、PR の `mergeCommit` が `origin/main` の祖先であること（`git merge-base --is-ancestor <mergeCommit> origin/main`）、branch tip の tree が squash mergeCommit の tree と完全一致すること（`git rev-parse <branch>^{tree}` == `<mergeCommit>^{tree}`）を確認済み。

> 注: 本リポジトリは squash merge 標準のため、`git merge-base --is-ancestor origin/<branch> origin/main`（branch tip 祖先チェック）は全件 false になる（branch tip は main に直接含まれない）。そのため PR 状態 + mergeCommit 祖先 + tree 完全一致の 3 点で統合済みを判定した。

| branch | 対応 PR | mergeCommit | 検証 |
|---|---|---|---|
| chore/remove-root-build-artifacts | #169 MERGED | `b53f3ada` | PR状態 / mergeCommit祖先 / tree一致 |
| feat/rn-ui-checkpoint-parity | #168 MERGED | `5f7cacac` | 同上 |
| fix/rn-release-route-gates | #170 MERGED | `5b59ba0f` | 同上 |
| docs/rn-identity-store-policy | #171 MERGED | `58b5a161` | 同上 |
| feat/rn-adr004-identity | #172 MERGED | `80238bd1` | 同上 |
| feat/rn-adr004-store-migration | #173 MERGED | `f6882511` | 同上 |
| fix/rn-release-gate-2 | #174 MERGED | `cd6a3583` | 同上 |
| chore/git-inventory-20260809b | #177 MERGED | `d6f1bc0b` | 同上（stale auto-PR #176 を先に CLOSE） |
| docs/checkpoint-docs-residual | #178 MERGED | `ddaf7753` | 同上 |
| chore/git-cleanup-20260809 | #179 MERGED | `ee61c1ef` | 同上 |
| feat/rn-tasks-real-data | #180 MERGED | `1aafdbcc` | 同上 |

**stale auto-PR #176 を CLOSE（`gh pr close 176 --comment`）**

同一 branch `chore/git-inventory-20260809b` の内容は #177 で squash merge 済みの重複 draft/auto-PR（`[Auto PR] chore/git-inventory-20260809b`）。CLOSE 後に branch 削除を実施。

### 14.2 保持した対象

| 対象 | 状態 |
|---|---|
| refs/remotes/wip/*（clean, v5, vocab） | 保持 |
| archive/*（macbook-worktree-20260802, pr-152-pre-rebase-20260802） | local ref 保持 |
| wip/rn-full-cutover-checkpoint-20260809 | 保持（メイン worktree HEAD） |
| codex/ui-reproduction-integration | local ref 保持 |
| fix/api-key-settings-docs | local ref 保持 |
| stash 22 件 | 保持 |
| 実在 DevSSD worktree に checkout 中の local branch | 保持（remote branch 削除は local branch に影響なし） |

### 14.3 検証

| コマンド | 結果 |
|---|---|
| `gh pr view 169/168/170/171/172/173/174/177/178/179/180` | 全件 `state=MERGED` |
| `git merge-base --is-ancestor <mergeCommit> origin/main` ×11 | 全件 true |
| `git rev-parse <branch>^{tree}` == `<mergeCommit>^{tree}` ×11 | 全件一致（内容欠損なし） |
| `gh pr list --state open` | 対象 11 branch のうち head を持つ OPEN PR は #176 のみ → CLOSE 後 0 件 |
| `gh pr close 176 --comment` | 成功 |
| `git push origin --delete` ×11 | 全件 `- [deleted]` を確認 |
| `git ls-remote origin`（削除対象 11 ref） | 0 件（残存なし） |
| 保持対象確認 | wip 3 / stash 22 / archive 2 / checkpoint 1 / ui-reproduction-integration / fix/api-key-settings-docs 残存 |
| `git diff --check` | pass |
| 変更ファイル | `docs/reviews/2026-08-09-git-branch-worktree-inventory.md` のみ |

### 14.4 未実施 / 保留

- stash 22 件の内容レビュー（別タスク）。
- B 分類の未統合 local branch の整理判断（PR 状態個別確認が必要）。
- 実在 worktree に checkout 中の branch の remote 側削除（#168〜#174 系など一部 worktree に checkout 中。local branch は残存しているため、対象 worktree の用途終了後に個別判断）。
