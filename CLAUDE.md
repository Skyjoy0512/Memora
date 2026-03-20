# Memora - Claude Code 協働ルール（TCA / 並列開発版）

## コミュニケーション
- すべての回答は日本語で行う
- 実装前に必ず「何をするか」を簡潔に説明する
- 出力は簡潔かつ構造的にする

## 作業の進め方（必須）
1. 関連ファイルを確認
2. 現状理解を日本語で整理
3. 実装方針を提示
4. 変更ファイル宣言
5. 実装

## 変更ファイル宣言（必須）
作業前に必ず以下を出力する：
- 変更するファイル
- 新規作成ファイル
- 変更しないファイル

※ 宣言していないファイルは変更禁止

## アーキテクチャ前提
- iOS 18+
- Swift 6 / Strict Concurrency
- SwiftUI
- TCA（The Composable Architecture）
- SwiftData
- SPM

## エージェント構成（固定）
- Claude A: Files / Recording / Import
- Claude B: FileDetail / Summary / Transcript
- Claude C: Projects / Todo / AskAI / Settings
- Claude D: Core / Repository / Pipeline / Integration / Bug Triage
- Codex: STT / Audio / Chunk / TranscriptionEngine

## 並列開発ルール（最重要）
### 責務分離
各エージェントは担当 Feature / 層のみ変更可能。

### TCA ベース変更制限
- 担当 Feature の Reducer / State / Action / View のみ変更可能
- 他 Feature の Reducer 変更は禁止
- 共通 Dependency の追加・変更は Claude D のみ

### Core / STT の責務
- PipelineCoordinator は Claude D のみ変更可能
- AudioRecorder / AudioPlayer / AudioChunker / TranscriptionEngine は Codex のみ変更可能
- UI は STT 内部を直接呼ばず、PipelineCoordinator 経由で扱う

### SwiftData 制約
- Model / Repository / Migration / Relationship 変更は Claude D のみ
- 他エージェントは SwiftData モデルを直接変更しない

### 共有ファイル制限
以下は原則変更禁止：
- project.pbxproj
- App エントリポイント
- 共通 Router
- 共有 DTO / public interface
- DependencyKey 定義

変更が必要な場合は、理由・影響範囲・追従が必要なファイルを先に示すこと。

### 禁止事項
- 担当外レイヤーの変更
- 無関係なリファクタリング
- 命名変更だけの修正
- ついで修正
- 他エージェント担当コードの勝手な修正

## エラー発生時の運用
### 単体ブランチでのエラー
- その担当が修正する

### 統合後のエラー
- Claude D が最初に原因分析する
- Claude D は「誰の責務か」を判定するところまで担当する
- 修正は元の責務担当へ返す
- 修正後に Claude D が再確認する

### 出力形式（エラー分析時）
- エラー要約
- 原因候補
- 最有力担当
- 副担当（必要なら）
- 最小修正案
- 再発防止策

## 完了時の報告（必須）
- 何を変更したか
- 変更ファイル一覧
- 影響範囲
- ビルドリスク
- 実機確認が必要な点
- 次にやるべきこと
- macOS / Xcode 側で必要な追加作業

## 実機確認が必要な処理
- 録音
- 音声再生
- 文字起こし
- ファイル保存 / 読み込み
- バックグラウンド
- 権限
- 長時間処理

## 成功条件
- 担当ブランチ単体で破綻しない
- 統合時に壊れにくい
- 原因追跡しやすい差分である
