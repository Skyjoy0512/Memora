# MEM-BASE-002: RN iOS AVAudio / SwiftData test fixture安定化

状態: 完了（2026-08-02、PR #155 merge済み）

## Objective

MEM-UI-002と非交差だったRN iOSテスト2件のfixtureを、製品コードを変えずにSimulatorで安定して検証できる状態にする。

## Scope

- `MemoraSharedStoreBridgeAdapterTests.swift`の無音WAV fixture
- `MemoraSummaryBridgeSecurityTests.swift`のSwiftData永続化assert
- `origin/main`起点の`codex/fix-rn-ios-test-fixtures`で独立実装
- source commit: `a6b90af7`

## Implementation

- AVAudio fixtureを44.1kHz Float32 non-interleaved standard format、4410 frames、明示的zero-fillへ変更した。
- Summary testは保存対象IDを保持し、generator実行後にfresh `ModelContext`から再fetchした永続値をassertするよう変更した。
- 変更は上記テスト2ファイルだけで、製品コードとMEM-UI-002には変更がない。

## Verification

- RN iOS `build-for-testing`: pass
- playback / summary対象2テストを各3回: 6 / 6 pass
- 関連4テストを直列実行: 4 / 4 pass
- RN iOS全体: 14 / 14 pass
- Claude read-only review: actionable findingsなし
- BASE-002→UI-002 integrationでもRN iOS全体14 / 14 pass、source branchはcleanかつ不変
- PR [#155](https://github.com/Skyjoy0512/Memora/pull/155)をmerge commit `669ce1f754bd859f5b78287cdb4432fa782a6af2`で`main`へ統合済み
- GitHub必須CI: 5 / 5 pass

## Out of scope

- `ExpoModulesProvider`重複警告
- `Podfile.lock` / generated `Pods/Manifest.lock`のchecksum drift
- Xcode SDK build `23F81a` / runtime build `23F73`の差

これらはテスト成功後も残るため、本タスクの修正原因とは扱わず別の基盤調査で追跡する。
