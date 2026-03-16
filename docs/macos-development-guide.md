# macOS 開発開始ガイド

## 概要

Claude Code をメインとして使用して、macOS 側で Xcode プロジェクトの作成から開発を進めるための手順を説明します。

## 前提条件

- **開発環境**: macOS
- **Xcode 16** 以上
- **Swift 6**
- **Claude Code**: メインとして使用中
- **TCA 1.17+**: Swift Package Manager でパッケージ解決

- **ファイル**: �画書 `Memora仕様書.txt` を参照

## 開発開始手順

### ステップ 1: プロジェクトの作成

#### 1. Xcode での新規プロジェクト作成
```bash
# 新規 iOS プロジェクトの作成
cd ~/Desktop/Memora

# Xcode プロジェクト作成
xcodebuild -project -scheme Memora -language Swift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -showDestination
```

#### 2. プロジェクト設定の確認
- Deployment Target: iOS 18.0 以上
- Swift Language Version: Swift 6
- Interface: SwiftUI
- Build Settings:
  - Swift 6 Language Mode: Strict Concurrency
  - Swift Compiler - Swift 5.9
  - Packaging: iOS

#### 3. 依存パッケージの追加
```bash
# Xcode で SPM の起動（Xcode プロジェクトを開いた状態）
cd ~/Desktop/Memora
xcodebuild -project Memora

# File > Add Package Dependencies
# swift-composable-architecture
# Version: 1.17.0 以上
```

#### 4. プロジェクトのビルド確認
```bash
# ビルドの確認
xcodebuild -scheme Memora clean build
```

### ステップ 2: 基本的なディレクトリ構成の作成

#### 1. ディレクトリの作成
```bash
# 基本ディレクトリ構成の作成
cd ~/Desktop/Memora

# App ディレクトリの作成
mkdir -p App

# Core ディレクトリの作成
mkdir -p Core

# Models ディレクトリの作成
mkdir -p Core/Models

# Persistence ディレクトリの作成
mkdir -p Core/Persistence

# Services ディレクトリの作成
mkdir -p Core/Services

# Utilities ディレクトリの作成
mkdir -p Core/Utilities

# Features ディレクトリの作成
mkdir -p Features

# Features/Files ディレクトリの作成
mkdir -p Features/Files

# Features/Files/FilesList ディレクトリの作成
mkdir -p Features/Files/FilesList

# Features/Files/Recording ディレクトリの作成
mkdir -p Features/Files/Recording

# Features/Files/Import ディレクトリの作成
mkdir -p Features/Files/Import

# Features/Files/Projects ディレクトリの作成
mkdir -p Features/Files/Projects

# Features/Files/Projects/ProjectsList ディレクトリの作成
mkdir -p Features/Files/Projects/ProjectsList

# Features/Files/Projects/ProjectDetail ディレクトリの作成
mkdir -p Features/Files/Projects/ProjectDetail

# Features/Todo ディレクトリの作成
mkdir -p Features/Todo

# Features/Todo/TodoList ディレクトリの作成
mkdir -p Features/Todo/TodoList

# Features/AskAI ディレクトリの作成
mkdir -p Features/AskAI

# Features/Settings ディレクトリの作成
mkdir -p Features/Settings

# DesignSystem ディレクトリの作成
mkdir -p DesignSystem

# DesignSystem/Theme ディレクトリの作成
mkdir -p DesignSystem/Theme

# DesignSystem/Components ディレクトリの作成
mkdir -p DesignSystem/Components
```

#### 2. ファイルの作成（最小限）

```bash
# 基本的なデータモデルの作成
touch Core/Models/AudioFile.swift
touch Core/Models/Project.swift
touch Core/Models/TodoItem.swift
```

#### 3. SwiftData セットアップ

```swift
// SwiftDataStack.swift
import SwiftData

@Model
final class SwiftDataStack {
    static let shared = ModelContainer(for: AudioFile.self, Project.self, TodoItem.self)
}
}
```

### ステップ 3: デザインシステムの実装

#### 1. カラートークンの実装
```bash
# DesignSystem/Theme/Colors.swift の作成
touch DesignSystem/Theme/Colors.swift
```

#### 2. タイポグラフィの実装
```bash
# DesignSystem/Theme/Typography.swift の作成
touch DesignSystem/Theme/Typography.swift
```

#### 3. コンポーネントの実装
```bash
# 共通コンポーネント
touch DesignSystem/Components/LiquidGlassModifier.swift
touch DesignSystem/Components/EmptyStateView.swift
```

### ステップ 4: 基本的な Reducer の実装

#### 1. FilesListReducer の実装
```bash
# Features/Files/FilesList/FilesListReducer.swift の作成
touch Features/Files/FilesList/FilesListReducer.swift
```

#### 2. FilesListView の実装
```bash
# Features/Files/FilesList/FilesListView.swift の作成
touch Features/Files/FilesList/FilesListView.swift
```

#### 3. FilesRowView の実装
```bash
# Features/Files/FilesList/FilesRowView.swift の作成
touch Features/Files/FilesList/FilesRowView.swift
```

#### 4. RecordingReducer の実装（モック）
```bash
# Features/Files/Recording/RecordingReducer.swift の作成
touch Features/Files/Recording/RecordingReducer.swift
```

#### 5. RecordingView の実装（モック）
```bash
# Features/Files/Recording/RecordingView.swift の作成
touch Features/Files/Recording/RecordingView.swift
```

#### 6. AppReducer の実装
```bash
# App/AppReducer.swift の作成
touch App/AppReducer.swift
```

#### 7. TabView の実装
```bash
# App/TabView.swift の作成
touch App/TabView.swift
```

### ステップ 5: MemoraApp.swift の更新

```swift
// MemoraApp.swift
import SwiftUI

import SwiftData

@main
struct MemoraApp: App {
    let modelContainer = try? ModelContainer(
        for: AudioFile.self, Project.self, TodoItem.self
    )

    var body: some Scene {
        WindowGroup {
            // TabView は作成後に追加される
            TabView()
        }
        .modelContainer(modelContainer)
    }
}
```

### ステップ 6: ビルド確認

```bash
# ビルドの確認
xcodebuild -scheme Memora clean build

# プロジェクトの確認
ls -la Memora
```

## 注意点

### Claude Code との連携方法

#### 基本的な使用フロー
1. **Windows 側**: コードの編集・設計・ドキュメント更新
2. **macOS 側**: Xcode での実装・テスト・デバッグ
3. **コミュニケーション**: GitHub を通じてコードを共有

#### プロンプトの指示方法
- **基本指示**: 各ファイル作成時に「# 貇示」を使ってください
- **環境指定**: 「macOS」「Windows」「両方の環境」を明確に指定
- **優先順位**: 「まずは〜次に〜」の手順で指示

#### エラーハンドリング
- テキストファイル: エラーが発生したら、具体的な修正指示を提供
- ��: 課明な指示を出すようになる

## 次のステップ

### ステップ 7: 最初のコミット

```bash
# macOS 側での開発開始完了後の最初のコミット
cd ~/Desktop/Memora
git add .
git commit -m "Initial macOS development start

- Create base Xcode project structure
- Implement basic directory structure
- Setup SwiftData Stack
- Add essential design system components
- Implement basic TCA reducers and views
- Prepare for AI services integration"
```

### ステップ 8: 定期的な同期

```bash
# macOS 側での作業完了後の同期
cd ~/Desktop/Memora
git pull origin master
```

## 開発の確認リスト

- [ ] Xcode プロジェクトの作成
- [ ] TCA 依存の追加
- [ ] 基本的なディレクトリ構成の作成
- [ ] SwiftData セットアップ
- [ ] デザインシステムの実装
- [ ] 基本的な Reducer の実装
- [ ] MemoraApp.swift の更新

## 成功条件

**成功の定義**:
- ✅ macOS 側で Xcode プロジェクトが作成され、ビルドエラーなく実行できる
- ✅ Claude Code との連携可能
- ✅ 基本的なディレクトリ構成が作成
- ✅ TCA アーキテクチャが整う
- ✅ Windows 側からの指示を受け取れる態勢
- ✅ コードレビュー可能な環境

## 今後の作業

### Windows 側での作業
1. ドキュメントの補足・修正
2. プランの調整
3. コードレビュー

### macOS 側での作業
1. Xcode プロジェクトでの実装
2. テスト
3. デバッグ
4. GitHub へのプッシュ

準備完了したので、macOS 側で開発を開始できます！