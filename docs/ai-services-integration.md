# AI サービス連携設計

## 概要

Claude Code をメインとして、複数の AI サービス（Codex、OpenAI、Anthropic、Gemini、DeepSeek など）を選択的に使用するためのアーキテクチャ設計。

## 現在の仕様書構造

現在の仕様書では以下の構造で AI サービスが定義されています：

```
Core/Services/
├── AudioRecorder.swift
├── AudioPlayer.swift
├── AudioChunker.swift
├── TranscriptionEngine.swift
├── SummarizationEngine.swift
├── DecisionExtractor.swift
├── TodoExtractor.swift
├── PipelineCoordinator.swift
├── LLMRouter.swift
├── LLMProviders/
│   ├── LocalLLMProvider.swift
│   ├── OpenAIProvider.swift
│   ├── AnthropicProvider.swift
│   ├── GeminiProvider.swift
│   └── DeepSeekProvider.swift
├── AuthService.swift
├── SubscriptionService.swift
└── AdService.swift
```

## 設計: 抽象化レイヤーの導入

### 1. AI サービスの標準化

#### LLMProvider プロトコルの定義

```swift
// Core/Services/LLMProviders/LLMProvider.swift
import Foundation

protocol LLMProvider: Sendable {
    var providerName: String { get }
    var isAvailable: Bool { get }
    func configure(apiKey: String) async throws
    func generateCompletion(prompt: String, context: String?) async throws -> String
}
```

#### 現在の LLMRouter を活用

```swift
// Core/Services/LLMRouter.swift
import Foundation

@MainActor
struct LLMRouter {
    static func provider(for type: LLMProviderType) -> LLMProvider {
        switch type {
        case .local:
            return LocalLLMProvider()
        case .openAI:
            return OpenAIProvider()
        case .anthropic:
            return AnthropicProvider()
        case .gemini:
            return GeminiProvider()
        case .deepSeek:
            return DeepSeekProvider()
        }
    }
}
```

### 2. 新しい AI サービスの追加

#### 容易な追加方法

新しい AI サービスを追加する際は以下のステップに従う：

1. **Core/Services/LLMProviders/[ProviderName]Provider.swift** を作成
2. **LLMProvider プロトコルを実装**
3. **LLMRouter のプロバイダー登録**
4. **TCA での連携**
5. **テスト**

### 3. Claude Code との連携

#### Claude Code での使用方法

Claude Code をメインとして使用する場合：

```swift
// Claude Code での使用例
import ComposableArchitecture

struct AIIntegrationState {
    var selectedProvider: LLMProviderType = .anthropic
    var apiKey: String = ""
    var isConfigured: Bool = false
}

enum LLMProviderType: String, Equatable {
    case local = "ローカル"
    case anthropic = "Anthropic"
    case openAI = "OpenAI"
    case gemini = "Gemini"
    case deepSeek = "DeepSeek"
}
```

### 4. 設定管理

#### API キー管理

```swift
// Core/Networking/APIKeyStore.swift
import Foundation
import Security

class APIKeyStore {
    static func save(key: String, value: String) throws {
        // Keychain への保存
    }

    static func load(key: String) throws -> String? {
        // Keychain からの読み込み
    }

    static func delete(key: String) throws {
        // Keychain からの削除
    }
}
```

### 5. エラーハンドリング

```swift
// エラーハンドリングの共通化
enum AIError: LocalizedError {
    case providerNotAvailable(String)
    case apiKeyMissing
    case networkError(Error)
    case rateLimitExceeded
    case parsingError(String)
}
```

## 実装計画

### フェーズ 1: 基本構造の拡張
1. LLMProvider プロトコルの標準化
2. LLMRouter の統合化
3. API キー管理の実装

### フェーズ 2: 設定 UI の実装
1. プロバイダー選択画面
2. API キー入力画面
3. 設定状態の表示

### フェーズ 3: テスト
1. 各プロバイダーのモック作成
2. 統合テストの実装

## 注意点

- **Claude Code メイン**: Claude Code をメインの AI サービス管理として使用
- **プロバイダーの追加**: 新しい AI サービスの追加は容易にできるように
- **API キーの安全**: Keychain を使用して API キーを安全に管理
- **エラーハンドリング**: 共通のエラー定義を使用して処理を統一
- **TCA 連携**: TCA の依存注入システムを使用して各 AI サービスと連携

## 次のステップ

1. **要件確認**: ユーザーに具体的な要件を確認
2. **設計の詳細化**: 具体的な実装計画の作成
3. **プロトタイプ実装**: 基本的な LLMProvider プロトコルから実装
