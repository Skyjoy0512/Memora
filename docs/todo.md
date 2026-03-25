# Memora - 開発タスク

## 今やること

### 基本構築（フェーズ1-6）
- [x] 仕様書の分析と計画立案
- [x] Windows側準備作業の完了
- [ ] macOS側でのXcodeプロジェクト作成
- [ ] TCA 依存パッケージの追加
- [ ] 基本的なディレクトリ構成の作成

### データモデルと永続化
- [ ] SwiftDataモデル定義（AudioFile, Project, TodoItem）
- [ ] SwiftDataStackの実装
- [ ] AudioFileRepositoryの実装
- [ ] RepositoryのDependencyKey登録

### デザインシステム
- [ ] カラートークン定義（ライトモードのみ）
- [ ] タイポグラフィトークン定義
- [ ] LiquidGlassModifierの実装
- [ ] EmptyStateViewの実装

### 基本的なUI
- [ ] FilesListReducerの実装
- [ ] FilesListViewの実装（空の状態のみ）
- [ ] FilesRowViewの実装
- [ ] RecordingReducerの実装（モック）
- [ ] RecordingViewの実装
- [ ] AppReducerの実装
- [ ] TabViewの実装（Filesタブのみ）

### 基本的なサービス
- [ ] AudioRecorderの基本実装（モック）
- [ ] MemoraApp.swiftのSwiftDataセットアップ

## 次にやること

### macOS側での作業（フェーズ1開始）
1. **Xcodeプロジェクト作成**
   - iOS 18+ をターゲット
   - Swift 6 言定
   - Strict Concurrency 有効
   - Interface: SwiftUI

2. **TCA依存の追加**
   - swift-composable-architecture 1.17+
   - SPMでパッケージ解決

3. **基本ディレクトリ構成の作成**
   - App/, Core/, Features/, DesignSystem/ ディレクトリ作成
   - 各サブディレクトリのグループ作成

4. **SwiftDataセットアップの実装**
   - モデル定義（AudioFile, Project, TodoItem）
   - SwiftDataStack
   - AudioFileRepository

5. **デザインシステムの実装**
   - カラートークン（ライトモード）
   - タイポグラフィトークン
   - LiquidGlassModifier
   - EmptyStateView

6. **Files一覧画面の実装**
   - FilesListReducer
   - FilesListView（空の状態）
   - FilesRowView

7. **基本的なReducerの実装**
   - RecordingReducer（モック）
   - RecordingView
   - AppReducer
   - TabView

8. **基本サービスの実装**
   - AudioRecorder（モック）
   - MemoraApp.swiftの更新

### Windows側での作業（並行対応）
1. **ドキュメントの更新**
   - 進捗状況の記録
   - 実装完了後のドキュメント更新

2. **計画の調整**
   - macOS側での実装状況に合わせて調整
   - 次のフェーズの計画立案

3. **GitHubの管理**
   - ブランチ戦略の確認
   - 必要に応じてブランチ作成

## 今後やること（フェーズ2以降）

### 拡張機能
- [ ] 実際の録音機能実装（AVFoundation使用）
- [ ] `SpeechAnalyzer -> SFSpeechRecognizer` のローカル文字起こし品質改善
- [ ] 要約生成機能
- [ ] プロジェクト管理機能
- [ ] Ask AI 機能

### STT コア強化
- [ ] SpeechAnalyzer 実機評価と失敗パターンの収集
- [ ] SFSpeechRecognizer フォールバック品質の確認
- [ ] 話者分離アルゴリズムの改善
- [ ] 話者サンプル抽出の設計
- [ ] 話者プロフィール保存モデルの設計
- [ ] 自分の声登録 UI の要件定義
- [ ] 自分の声ラベル付けまたは除外ロジックの設計
- [ ] Omi 参照の話者埋め込みマッチング方式の比較

### UI/UX 拡張
- [ ] ダークモード対応
- [ ] 他のタブ実装（Projects, Todo, Settings）
- [ ] アニメーションの追加
- [ ] アクセシビリティ対応

### データ管理拡張
- [ ] iCloud 同期
- [ ] データのエクスポート・インポート
- [ ] マイグレーション管理

### テスト
- [ ] 単体テストの実装
- [ ] UI スナップショットテスト
- [ ] TCA テストの追加

### データモデル実装
- [ ] Recording モデル作成
- [ ] Project モデル作成
- [ ] Transcription モデル作成
- [ ] Speaker モデル作成

### 基本的な UI コンポーネント
- [ ] FileCard コンポーネント作成
- [ ] ToastView コンポーネント作成
- [ ] LoadingView コンポーネント作成

## 次にやること

### ホーム画面（Files タブ）
- [ ] プロジェクト一覧表示
- [ ] 録音一覧表示
- [ ] 新規プロジェクト作成ボタン
- [ ] 新規録音開始ボタン

### 録音機能
- [ ] 録音画面の実装
- [ ] AudioService の基本実装
- [ ] 録音コントロール UI
- [ ] 録音データの保存

### 文字起こし（モック）
- [ ] 文字起こし画面の実装
- [ ] モックデータの作成
- [ ] 文字起こしテキストの表示
- [ ] 話者ラベル UI（Speaker 1/2...）

### 要約（モック）
- [ ] 要約画面の実装
- [ ] モックデータの作成
- [ ] 要約テキストの表示

## 今後やること

### API 統合
- [ ] 文字起こし API の選定と実装
  - OpenAI Whisper API
  - Speech-to-Text API (Google)
  - ローカル Speech Framework
- [ ] オンデバイス Whisper 導入判断
  - 現時点では見送り
  - 初回起動 UX、モデルサイズ、発熱が許容範囲なら再検討
- [ ] 要約 API の選定と実装
  - OpenAI GPT API
  - Anthropic Claude API
  - 他の要約サービス
- [ ] エラーハンドリングの実装
- [ ] リトライ処理の実装

### 拡張機能
- [ ] Ask AI 機能
  - AI チャット画面
  - 文字起こし内容との対話
  - 質問・回答の履歴
- [ ] 添付資料管理
  - 資料のアップロード
  - 資料のプレビュー
  - 資料と録音の紐付け
- [ ] エクスポート機能
  - テキスト形式
  - PDF 形式
  - 他形式の検討

### UI/UX 改善
- [ ] アニメーションの追加
- [ ] ダークモード対応
- [ ] フォントサイズ調整
- [ ] アクセシビリティ対応

### データ管理
- [ ] SwiftData/CoreData の実装
- [ ] iCloud 同期の実装
- [ ] データのエクスポート・インポート
- [ ] バックアップ機能

### テスト
- [ ] 単体テストの実装
- [ ] UI テストの実装
- [ ] 統合テストの実装

### デプロイ・リリース
- [ ] App Store Connect の設定
- [ ] プロビジョニングプロファイルの作成
- [ ] スクリーンショットの作成
- [ ] App Store 審査対応

## 優先順位の考え方

### 高優先度
- ユーザーが基本的な機能を使えるようにする
- 録音 → 文字起こし → 要約 の基本フロー
- データの永続化

### 中優先度
- API 統合（モックから本実装へ移行）
- 拡張機能の実装
- UI/UX の改善

### 低優先度
- 高度な機能
- 統合機能
- テスト・デプロイ（開発初期段階では）

## 進捗管理

### マイルストーン
1. **MVP (Minimum Viable Product)**
   - 録音、文字起こし（モック）、要約（モック）の基本フロー
   - データ保存（ローカル）

2. **Alpha 版**
   - API 統合完了
   - 基本的な UI/UX 完成
   - テスト導入

3. **Beta 版**
   - 拡張機能実装
   - UI/UX 完成
   - テスト完了

4. **リリース版**
   - App Store 審査対応
   - バグ修正
   - パフォーマンス最適化
