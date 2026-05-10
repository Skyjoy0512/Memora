# Memora UI Parallel Development Plan

この計画は `docs/Memora_UI_Reproduction_Spec_for_ClaudeCode.md` をClaudeCodeのgit worktree並列開発に合わせて実装するための分担表です。目的は、ClaudeCodeの親セッションが複数worktree/サブタスクに分解してもコンフリクトを最小化し、スクリーンショット一致を最優先で進めることです。

## 共通ルール

- 全員、最初に `docs/Memora_UI_Reproduction_Spec_for_ClaudeCode.md` を読む。
- 親ClaudeCodeは自分で実装しすぎず、worktree作成、分担、進捗確認、統合、最終QAを担当する。
- 各worktreeは必ず担当Workstreamだけを実装する。
- 標準NavigationBar/List/TabViewの自動余白でスクショとズレる場合は、カスタムレイアウトを優先する。
- iOS 26のLiquid Glassは `glassEffect` / `GlassEffectContainer` を使う。
- iOS 17-25はMaterial系フォールバックを必ず残す。
- 既存機能、データ取得、遷移、生成処理は壊さない。
- 既に `Memora/Views/HomeView.swift` に入っている差分は参考実装として扱う。設計書と違う場合は設計書を優先する。
- 各担当は、他担当のファイルを原則編集しない。必要なら事前に理由を報告する。

## ClaudeCode Worktree前提の進め方

ClaudeCodeには、親セッションに以下を依頼する。

1. 現在の作業ツリーを確認する。
2. 未コミット差分を把握し、UI設計書だけをベースにした共通ブランチを作る。
3. その共通ブランチからworktreeを複数作成する。
4. Workstreamごとに1つのworktreeで実装する。
5. 各worktreeでビルド確認する。
6. 統合用ブランチへ順番にマージする。
7. 統合後にスクショQAと最終ビルドを実行する。

重要:

- 未コミットの `Memora/Views/HomeView.swift` 差分は、前回の参考実装です。ClaudeCodeに完全実装させる場合は、親セッションが最初にこの差分をどう扱うか決めること。
- おすすめは、設計書2本だけを先にコミットして共通ベースにし、`HomeView.swift` の既存差分は参考として残すか、別ブランチへ退避すること。
- worktreeを切る前のベースブランチに不要な実装差分が混ざると、全worktreeがその差分を引き継ぐため注意。

## 推奨ブランチ/worktree構成

- `codex/ui-foundation`
- `codex/ui-home`
- `codex/ui-device-detail`
- `codex/ui-file-detail-shell`
- `codex/ui-generation-sheets`
- `codex/ui-generated-content`

統合ブランチ:

- `codex/ui-reproduction-integration`

worktreeディレクトリ例:

- `../Memora-ui-foundation`
- `../Memora-ui-home`
- `../Memora-ui-device-detail`
- `../Memora-ui-file-detail-shell`
- `../Memora-ui-generation-sheets`
- `../Memora-ui-generated-content`

最後に統合用ブランチで順番にマージする。

## 親ClaudeCodeに投げるプロンプト

```text
MemoraのUI再現を、git worktreeを使って並列開発できるように進めてください。

必ず読む設計書:
- docs/Memora_UI_Reproduction_Spec_for_ClaudeCode.md
- docs/Memora_UI_Parallel_Development_Plan.md

あなたは親オーケストレーターです。直接大きく実装せず、worktreeを作成してWorkstream A-Fへ分割してください。

最初にやること:
1. git statusで未コミット差分を確認してください。
2. docs/Memora_UI_Reproduction_Spec_for_ClaudeCode.md と docs/Memora_UI_Parallel_Development_Plan.md を共通仕様として扱ってください。
3. 既に Memora/Views/HomeView.swift に入っている差分は参考実装です。設計書と矛盾する場合は設計書を優先してください。
4. worktreeを切る前に、ベースに含める差分と含めない差分を明確にしてください。迷う場合は実装前に報告してください。

worktree方針:
- codex/ui-foundation: Workstream A
- codex/ui-home: Workstream B
- codex/ui-device-detail: Workstream C
- codex/ui-file-detail-shell: Workstream D
- codex/ui-generation-sheets: Workstream E
- codex/ui-generated-content: Workstream F

各worktreeへの指示:
- 担当Workstream以外のファイルは原則編集しない。
- 不要なリファクタをしない。
- スクリーンショット差分が限りなく少なくなることを最優先にする。
- iOS 26 Liquid Glassは glassEffect / GlassEffectContainer を使う。
- iOS 17-25 fallbackを残す。
- 各worktreeで xcodebuild -scheme Memora -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build を実行する。

統合順:
1. codex/ui-foundation
2. codex/ui-home
3. codex/ui-device-detail
4. codex/ui-file-detail-shell
5. codex/ui-generation-sheets
6. codex/ui-generated-content

統合後:
- 最終ビルドを実行してください。
- 主要状態のスクショQAを行い、docs/Memora_UI_Reproduction_Spec_for_ClaudeCode.md の Pixel QA Checklist に沿って残差分を列挙してください。
- 最後に変更ファイル、各worktreeの成果、残課題を報告してください。
```

## worktree作成コマンド例

ClaudeCodeが自動で実行する想定だが、手動でやる場合は以下。

```bash
git switch -c codex/ui-reproduction-base
git add docs/Memora_UI_Reproduction_Spec_for_ClaudeCode.md docs/Memora_UI_Parallel_Development_Plan.md
git commit -m "Add Memora UI reproduction specs"

git worktree add ../Memora-ui-foundation -b codex/ui-foundation
git worktree add ../Memora-ui-home -b codex/ui-home
git worktree add ../Memora-ui-device-detail -b codex/ui-device-detail
git worktree add ../Memora-ui-file-detail-shell -b codex/ui-file-detail-shell
git worktree add ../Memora-ui-generation-sheets -b codex/ui-generation-sheets
git worktree add ../Memora-ui-generated-content -b codex/ui-generated-content
```

注意:

- `git worktree add -b` は現在HEADを起点にする。起点に含めたくない差分がある場合は、先にstash/commit/別ブランチ退避を行う。
- `HomeView.swift` の参考実装をベースに含めたくないなら、worktree作成前に退避する。

## Workstream A: UI Foundation

担当範囲:

- Liquid Glass共通コンポーネント
- Floating button/card/sheetの共通部品
- 色・寸法・影の補助定数
- スクショ一致用の軽量UI部品

主な編集候補:

- `Memora/DesignSystem/Components/LiquidGlassModifier.swift`
- `Memora/DesignSystem/Components/` に新規追加
- `Memora/DesignSystem/Colors.swift`
- `Memora/DesignSystem/Spacing.swift`

作るもの:

- `GlassPillButton`
- `GlassCircleButton`
- `FloatingGlassTabBar`
- `AskAnythingBar`
- `CustomBottomGlassSheet`
- `ScreenshotMatchedSkeleton`

触らない:

- `HomeView.swift`
- `FileDetailView.swift`
- `DeviceDetailView.swift`

完了条件:

- 共通部品だけでビルド成功。
- iOS 26 availability gateが正しい。
- iOS 17-25 fallbackがある。

## Workstream B: Home

担当範囲:

- ホーム通常ファイル一覧
- プロジェクトタブ
- FAB通常/展開
- 下部Floating Tab Barとの接続
- ホーム上のAsk Anythingバー表示

主な編集候補:

- `Memora/Views/HomeView.swift`
- `Memora/App/ContentView.swift`
- 必要なら `Memora/DesignSystem/Components/Home*.swift` 新規追加

依存:

- Workstream Aの共通部品があると理想。
- Aが未完でも、ローカルprivate componentで先に実装してよい。ただし統合時に共通部品へ寄せる。

触らない:

- `FileDetail/*`
- `DeviceDetailView.swift`

完了条件:

- ホーム/ファイル一覧がスクショ一致。
- ホーム/プロジェクトタブがスクショ一致。
- FAB展開状態がスクショ一致。
- `xcodebuild` 成功。

## Workstream C: Device Detail

担当範囲:

- `PLAUD Note Pro` タップ先のデバイス詳細画面
- PLAUDデバイス画像表示
- バッテリー/ページインジケータ/情報カード/解除ボタン

主な編集候補:

- `Memora/Views/DeviceDetailView.swift`
- `Memora/Resources/Assets.xcassets` または既存画像アセット置き場

依存:

- Workstream Aの `GlassCircleButton` があると理想。

触らない:

- `HomeView.swift` は遷移口が既にある前提。必要な場合のみ最小修正。
- `FileDetail/*`

完了条件:

- デバイス詳細スクショに近い配置。
- PLAUD画像は仮ではなく、用意できるアセットを使う。なければ明確に未完として報告。
- `xcodebuild` 成功。

## Workstream D: File Detail Shell

担当範囲:

- 音声ファイル詳細の共通シェル
- 上部戻る/再生/共有/三点ボタン
- タブ `要約` / `文字起こし` / `メモ`
- タイトル/日時/画像アップロード/サムネイル列
- 生成前の空状態
- Ask Anything overlay位置

主な編集候補:

- `Memora/Views/FileDetail/FileDetailView.swift`
- `Memora/Views/FileDetail/FileDetailHeader.swift`
- `Memora/Views/FileDetail/PlayerControls.swift`
- 必要なら `Memora/Views/FileDetail/FileDetailShell*.swift` 新規追加

依存:

- Workstream Aのガラスボタン/AskAnythingBarがあると理想。

触らない:

- `SummaryTab.swift`
- `TranscriptTab.swift`
- `MemoTab.swift`
- 生成ボトムシート実装

完了条件:

- 生成前スクショに近い。
- 標準NavigationBarを使っていない。
- Ask Anythingバーがスクショ通りoverlayされる。
- `xcodebuild` 成功。

## Workstream E: Generation Sheets

担当範囲:

- 生成方式選択ボトムシート
- テンプレート選択ボトムシート
- AIモデル選択ボトムシート
- 生成中スケルトン

主な編集候補:

- `Memora/Views/FileDetail/FileDetailView.swift` は状態接続のみ最小限
- `Memora/Views/GenerationFlowSheet.swift`
- 必要なら `Memora/Views/FileDetail/Generation*.swift` 新規追加

依存:

- Workstream Aの `CustomBottomGlassSheet`。
- Workstream Dの状態名とトリガー。

触らない:

- Home
- Device Detail
- Summary/Transcript本文UI

完了条件:

- 3種類のボトムシートがスクショ一致。
- 背景ディム、ドラッグインジケータ、下部生成ボタンが一致。
- 生成中スケルトンがスクショ一致。
- `xcodebuild` 成功。

## Workstream F: Generated Content Tabs

担当範囲:

- 生成後の要約タブ
- 生成後の文字起こしタブ
- メモタブ空状態
- 長文表示密度、画像サムネイル、Ask Anything overlayとの重なり

主な編集候補:

- `Memora/Views/FileDetail/SummaryTab.swift`
- `Memora/Views/FileDetail/TranscriptTab.swift`
- `Memora/Views/FileDetail/MemoTab.swift`
- 必要なら `Memora/Views/FileDetail/Generated*.swift` 新規追加

依存:

- Workstream DのFile Detail Shell。

触らない:

- Home
- Device Detail
- Generation sheets

完了条件:

- 要約/文字起こし/メモの3状態がスクショ一致。
- 長文のフォントサイズ、行間、左右余白がスクショに近い。
- `xcodebuild` 成功。

## 統合順

1. Workstream A: UI Foundation
2. Workstream B: Home
3. Workstream C: Device Detail
4. Workstream D: File Detail Shell
5. Workstream E: Generation Sheets
6. Workstream F: Generated Content Tabs

D/E/Fは並列可能だが、統合時はDを先に入れる。E/FはDのシェル構造に合わせて軽く調整する。

## ClaudeCodeに投げる共通プロンプト

```text
MemoraのUI再現を担当してください。

必ず読む設計書:
- docs/Memora_UI_Reproduction_Spec_for_ClaudeCode.md
- docs/Memora_UI_Parallel_Development_Plan.md

あなたの担当Workstreamは「{WORKSTREAM_NAME}」です。

重要:
- 担当範囲外のファイルは原則編集しないでください。
- 他のWorkstreamも同時に作業している前提で、不要なリファクタや広範囲変更は避けてください。
- スクリーンショット差分が限りなく少なくなることを最優先にしてください。
- 標準NavigationBar/List/TabViewの自動余白でズレる場合は、カスタムレイアウトを優先してください。
- iOS 26のLiquid Glassは glassEffect / GlassEffectContainer を使ってください。
- iOS 17-25 fallbackも残してください。
- 実装後は `xcodebuild -scheme Memora -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build` を実行してください。

完了時に報告すること:
- 変更ファイル
- 実装した状態
- 未実装/未確認のスクショ差分
- ビルド結果
```

## Workstream別プロンプト

### A用

```text
担当Workstream: A UI Foundation

Liquid Glass、Floating UI、Ask Anything、スケルトンなどの共通部品だけを実装してください。
Home/FileDetail/DeviceDetailの画面本体は編集しないでください。
```

### B用

```text
担当Workstream: B Home

ホーム通常ファイル一覧、プロジェクトタブ、FAB展開、Floating Tab Bar、ホーム上のAsk Anything表示を実装してください。
FileDetailとDeviceDetailは編集しないでください。
```

### C用

```text
担当Workstream: C Device Detail

PLAUD Note Proタップ先のデバイス詳細画面を実装してください。
HomeViewは遷移口の最小修正のみ許可します。
```

### D用

```text
担当Workstream: D File Detail Shell

音声ファイル詳細の共通シェル、上部ボタン、タブ、タイトル、画像アップロード、生成前空状態、Ask Anything overlayを実装してください。
SummaryTab/TranscriptTab/MemoTabの生成後本文と生成ボトムシートは編集しないでください。
```

### E用

```text
担当Workstream: E Generation Sheets

生成方式選択、テンプレート選択、AIモデル選択、生成中スケルトンを実装してください。
FileDetail本体は状態接続の最小修正だけにしてください。
```

### F用

```text
担当Workstream: F Generated Content Tabs

生成後の要約、文字起こし、メモ空状態を実装してください。
ボトムシートやHome/DeviceDetailは編集しないでください。
```
