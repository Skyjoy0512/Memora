あなたは Memora リポジトリの Claude Code 実行エージェントです。
このセッションでは **CO-01: STT Diagnostics & Backend Settings UI** を完了させてください。

# 0. 最初に読むファイル
1. `CLAUDE.md`
2. `docs/v1-product-design.md`
3. `docs/agent-status-board.md`

# 1. タスク概要
- **Task ID**: CO-01
- **Owner**: Codex（Claude Code セッションで代行）
- **Priority**: P1
- **Parallel lane**: Codex-S
- **Depends on**: CL-01（DONE — contract freeze 済み）

# 2. 目的
SpeechAnalyzer / legacy fallback の状態を user-visible にする。
CL-01 で安定化した STT backend の診断情報を設定画面から確認できるようにする。

# 3. 変更対象ファイル
- `Memora/Views/SettingsView.swift` — STT 診断セクションの改善
- `Memora/Views/DebugLogView.swift` — 診断ログの表示強化（必要なら）
- `Memora/Views/Components/STTDiagnosticsCard.swift`（新規作成、SettingsView から分離）

### 変更しないファイル（絶対に触らない）
- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/STTSupportTypes.swift`
- `Memora/Core/Services/TranscriptionEngine.swift`
- `Memora/Core/Networking/AIService.swift`
- `Memora/Core/Services/SpeechAnalyzerPreflight.swift`
- `Memora/App/MemoraApp.swift`
- `Memora/App/ContentView.swift`
- `Memora/Views/AskAIView.swift`
- `Memora/Views/FileDetailView.swift`
- `Memora/Core/ViewModels/FileDetailViewModel.swift`
- `Memora/Core/Models/ProcessingJob.swift`
- `Memora/Core/Services/PipelineCoordinator.swift`

# 4. 現状理解（コードから読み取った事実）

## SettingsView.swift の現状
- `transcriptionSettingsSection` に文字起こしモード Picker あり（line 114-198）
- SpeechAnalyzer feature toggle が既に実装済み（line 155-176）
  - iOS 26.0+ で Toggle 表示
  - ON 時に警告テキスト表示
- `STTDiagnosticsView()` への NavigationLink が既にあり（line 178-197）
  - "STT 診断" ラベル、backend 状態/asset 状態/フォールバック理由の確認

## STTDiagnosticsView の現状（SettingsView.swift 内 private struct、line 1649-）
- `STTDiagnosticsSnapshot` を表示
- `STTDiagnosticsRunner.makeSnapshot()` で非同期取得
- backend panel / asset panel を `STTDiagnosticsCard` で表示
- "診断を実行" ボタンでスナップショット取得
- last recorded entry から直近の STT 実行診断を表示

## STTDiagnosticsCard の現状（SettingsView.swift 内 private struct、line 2301-）
- `STTDiagnosticsPanel` をカード形式で表示
- tone に応じた色分け（success/warning/error）

## STTDiagnosticsRunner の現状（SettingsView.swift 内 private enum、line 1898-）
- API mode / Local mode で異なるスナップショット生成
- Local + SpeechAnalyzer ON: preflight 実行 or quick inspection
- Local + SpeechAnalyzer OFF / iOS < 26: SFSpeechRecognizer 可用性チェック
- `SpeechAnalyzerInspection` / `STTDiagnosticsSnapshot` / `STTDiagnosticsPanel` 等の型が全て SettingsView.swift 内に private 定義

## 問題点
1. **診断 UI 関連の型が全て SettingsView.swift 内に private 定義** — STTDiagnosticsCard, STTDiagnosticsSnapshot, STTDiagnosticsPanel, STTDiagnosticsTone, STTDiagnosticsRunner, SpeechAnalyzerInspection 等が 600行以上を占める
2. **FileDetailView の STT backend 診断表示が限定的** — fallback 理由は出るが、設定画面との連携がない
3. **STTDiagnosticsCard が再利用不可能** — private struct のため他の画面から使えない

# 5. 実装要件

### コンポーネント分離
1. `STTDiagnosticsCard` を `Memora/Views/Components/STTDiagnosticsCard.swift` に分離
   - `STTDiagnosticsPanel` / `STTDiagnosticsTone` も一緒に移動
   - internal アクセスに変更
2. `STTDiagnosticsSnapshot` / `STTDiagnosticsRunner` / `SpeechAnalyzerInspection` を `Memora/Views/Components/STTDiagnosticsTypes.swift` に分離
   - `STTDiagnosticsView` は SettingsView.swift 内に残してもよいし、Components に移動してもよい（最小差分優先）

### SettingsView の改善
1. 分離後の型を import して既存の STTDiagnosticsView が動くことを確認
2. transcriptionSettingsSection 内の SpeechAnalyzer 説明テキストを改善:
   - preflight が CL-01 で強化されたことを反映
   - "ベータ機能です。クラッシュする場合はオフにしてください。" の警告をより適切な表現に（preflight で守られていることを反映）
3. STT 診断セクションに以下を追加（既存スナップショットに含まれていない場合）:
   - SpeechAnalyzer preflight の最終結果（pass/fail/skip）
   - 音声フォーマット変換の有無
   - 現在の fallback chain の順序（SpeechAnalyzer → SFSpeechRecognizer → API）

### 最小差分の方針
- 大規模な UI 再設計はしない
- 型の移動とアクセス変更が主目的
- 既存の動作を壊さない

# 6. 受け入れ条件
- STT の状態が UI から確認できる（既存機能を維持）
- STTDiagnosticsCard が独立コンポーネントとして再利用可能
- crash した/失敗した理由が再現しやすくなる
- build が通る

# 7. 実装方針（最小差分）

### Step 1: 型の分離
- `Memora/Views/Components/STTDiagnosticsCard.swift` を作成
  - `STTDiagnosticsCard: View`
  - `STTDiagnosticsPanel`
  - `STTDiagnosticsTone`
- `Memora/Views/Components/STTDiagnosticsTypes.swift` を作成
  - `STTDiagnosticsSnapshot`
  - `STTDiagnosticsRunner`
  - `SpeechAnalyzerInspection`
  - 関連するヘルパー
- 全て internal アクセスに変更

### Step 2: SettingsView の更新
- 分離した型を参照するように修正
- private 定義を削除
- SpeechAnalyzer 警告テキストの改善

### Step 3: 動作確認
- SettingsView の STT 診断 NavigationLink が正常動作すること
- "診断を実行" ボタンが正常動作すること

# 8. 検証
- `xcodebuild -project Memora.xcodeproj -scheme Memora -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' build`
- 失敗したら原因・回避策を書く

# 9. 完了時の出力形式
以下の順で日本語で報告:
- 変更概要
- 変更ファイル一覧
- 実装した理由
- 検証結果
- 未確認事項
- 次に Claude が取るべき READY task

# 10. ブランチ・PR
- ブランチ: `feat/co-01-stt-diagnostics-ui`
- コミットメッセージ: `refactor: extract STT diagnostics components from SettingsView into reusable modules (CO-01)`
- PR 作成後、`docs/agent-status-board.md` の CO-01 を DONE に更新

# 11. 禁止事項
- broad rewrite 禁止
- 依頼範囲外のついでリファクタ禁止
- `main` への直接 push 禁止
- STT コアファイルへの変更禁止
- 診断ロジック（STTDiagnosticsRunner）の動作変更禁止（移動のみ）
