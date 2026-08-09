# Git Branch / Worktree 棚卸し（2026-08-09）

## 1. 目的とスコープ

- 現在見えている refs だけで全 worktree と主要 local/remote branches を棚卸しし、安全に整理可能な対象を洗い出す。
- **この調査は完全に read-only**。ソース、既存 docs、branch、worktree、stash、remote は一切変更・削除しない。
- `git fetch -p` は remote-tracking を変更するため**使用禁止**。`git fetch` 自体も実行していない（既存の refs のみを使用）。
- 本ドキュメント（`docs/reviews/2026-08-09-git-branch-worktree-inventory.md`）の作成以外の変更は行わない。

## 2. 前提情報

| 項目 | 値 |
|---|---|
| git version | 2.50.1 (Apple Git-155) |
| remote | `origin https://github.com/Skyjoy0512/Memora.git` |
| origin/HEAD | `refs/remotes/origin/main` |
| origin/main tip | `3c12f140 feat(rn-ui): add HeroUI provider foundation (#162)` |
| 作業中ブランチ | `chore/git-inventory-20260809`（origin/main と同一 commit、working tree clean） |

### 件数サマリ

| 対象 | 件数 |
|---|---|
| local branches | 104 |
| remote origin/* branches（origin/HEAD 含む） | 84 |
| PR refs（`refs/remotes/pr/*`） | 5（pr/140, 141, 143, 144, 146） |
| WIP refs（`refs/remotes/wip/*`） | 3（wip/clean, wip/v5, wip/vocab） |
| 登録 worktree | 36 |
| worktree lock | 7 |
| path 不明（missing）の worktree | 7（= lock 7 と同一セット） |
| stash | 22 |

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
