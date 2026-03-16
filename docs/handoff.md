# Memora - 引き継ぎ情報

## 現在の状態

### プロジェクト進捗
- **フェーズ**: 初期設計・準備完了
- **開発開始**: 未実装（これから Xcode プロジェクト作成）
- **完了済み**: プロジェクト構成・ドキュメント整備

### 完了した作業
- [x] CLAUDE.md 作成（Claude Code 協働ルール）
- [x] .claude/settings.json 作成（セキュリティ設定）
- [x] .gitignore 作成（iOS 開発対応）
- [x] docs/architecture.md 作成（アーキテクチャ設計）
- [x] docs/todo.md 作成（タスク管理）
- [ ] README.md 作成
- [ ] Xcode プロジェクト作成
- [ ] git リポジトリ初期化

### 現在の環境
- **OS**: Windows / macOS ハイブリッド対応を目指す設計
- **開発環境**: Xcode (macOS), VS Code (Windows)
- **言語**: Swift 5.9+, SwiftUI
- **ターゲット**: iOS 17+

## 次に推奨する作業

### すぐにやること（優先度高）

1. **README.md の作成**
   - プロジェクト概要
   - 開発方針の説明
   - クイックスタートガイド

2. **git リポジトリの初期化**
   ```bash
   git init
   git add .
   git commit -m "Initial commit: Memora project setup"
   ```

3. **Xcode プロジェクトの作成**（macOS で）
   - SwiftUI プロジェクトを作成
   - タブナビゲーションの実装
   - 基本的なファイル構成の作成

4. **基本的な UI フレームワーク**
   - Home/Files タブ
   - 録音画面の基本構造
   - 文字起こし画面の基本構造

### 次にやること（優先度中）

1. **データモデルの実装**
   - Recording, Project, Transcription, Speaker モデル
   - SwiftData/CoreData の導入

2. **モックデータの作成**
   - サンプル録音データ
   - サンプル文字起こしデータ
   - サンプル要約データ

3. **基本的なサービス**
   - AudioService（録音・再生）
   - StorageService（データ保存）

### 今後の作業（優先度低）

1. **API 統合**
   - 文字起こし API 選定
   - 要約 API 選定

2. **拡張機能**
   - Ask AI 機能
   - 添付資料管理

## 環境設定

### macOS 側で必要なこと
1. **Xcode のインストール**
   - Xcode 15 以上
   - Command Line Tools のインストール

2. **プロジェクト作成**
   - `File > New > Project`
   - iOS → App
   - Interface: SwiftUI
   - Language: Swift

3. **シミュレータの準備**
   - iOS 17 シミュレータ

### Windows 側でできること
1. **ドキュメントの確認・更新**
2. **コードレビュー**
3. **要件の調整・確認**
4. **Claude Code での設計・計画**

## 開発フロー

### Windows / macOS 協働フロー
1. **Windows 側**
   - ドキュメント更新
   - 設計・計画
   - 要件調整

2. **macOS 側**
   - Xcode での実装
   - テスト実行
   - ビルド確認

3. **共通**
   - git でのコード管理
   - Claude Code での協働開発

### Claude Code の活用
- 設計・計画: Windows 側で可能
- 実装支援: macOS 側で Xcode プロジェクト作成後
- コードレビュー: 両方の環境で可能

## メモ

### 重要なファイル
- `CLAUDE.md`: Claude Code との協働ルール
- `docs/architecture.md`: アーキテクチャ設計
- `docs/todo.md`: 開発タスク管理

### セキュリティ上の注意
- API キーなどの秘密情報は `.gitignore` で除外済み
- `.env` ファイルは Claude Code から読み取り制限済み
- 有料サービスの利用は事前に相談

### UI/UX のポイント
- ミニマルでクリーンなデザイン
- モノトーン基調
- iOS ネイティブの操作感
- 過度な装飾を避ける

### 技術的な注意点
- SwiftUI を中心に実装
- iOS 17+ をターゲット
- モックデータで開発を進める
- API は後から導入可能な構造に

## 連絡先・相談事項

### 設計・仕様に関する相談
- UI/UX の方向性
- 機能の優先順位
- API の選定
- 技術的な決定事項

### 開発進捗の共有
- タスクの進捗状況
- 障害・問題点
- 要件の変更・追加

### 引き継ぎ時に確認すべきこと
1. 現在の開発フェーズ
2. 完了したタスク
3. 進行中のタスク
4. 次に優先すべきタスク
5. 技術的な決定事項
6. 未解決の問題・課題
