# Claude Code 利用制限対応案

## 背景

Claude Code の利用制限に達しているため、Claude Code だけでなく、Codex などの他の AI サービスも使用する必要があります。

## 問題分析

### 現在の状況
- **Claude Code**: メインの AI サービス管理として使用中
- **利用制限**: レート制限、トークン制限に達している可能性
- **開発制限**: Claude Code での開発が一時的に停止する可能性

### どのような制限？
1. **API レート制限**: 1 時間あたりの API 呼び回数制限
2. **トークン制限**: 1 日間あたりのトークン制限
3. **コンテキスト制限**: 1 セッションのコンテキストウィンドウサイズ制限
4. **利用時間制限**: 1 日あたりの最大利用時間

## 解決策

### 選択肢 A: AI サービスの分散利用（推奨）

#### 設計
```swift
// 各 AI サービスに個別の Claude Code インスタンスを管理
import ComposableArchitecture

struct AIIntegrationState {
    var activeProviders: [LLMProviderType] = [.anthropic]
    var providerStates: [LLMProviderType: AIIntegrationState] = [:]
}

struct AIIntegrationReducer {
    @ObservableState
    struct State: Equatable {
        var selectedProvider: LLMProviderType = .anthropic
        var providerAPIKeys: [LLMProviderType: String] = [:]
        var isConfigured: [LLMProviderType: Bool] = [:]
        var errorMessages: [LLMProviderType: String?] = [:]
    }

    enum Action {
        case selectProvider(LLMProviderType)
        case configureProvider(LLMProviderType, String)
        case switchProvider(LLMProviderType)
    }
}

@Dependency(\.llmProviderAnthropic) var anthropicProvider
@Dependency(\.llmProviderOpenAI) var openAIProvider
@Dependency(\.llmProviderGemini) var geminiProvider
@Dependency(\.llmProviderDeepSeek) var deepSeekProvider
@Dependency(\.llmProviderLocal) var localProvider

var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .selectProvider(let provider):
            state.selectedProvider = provider
            state.providerStates[provider] = .notConfigured
            return .run { send in
                try await state.providerStates[provider]?.configure(apiKey: "")
                await send(.providerConfigured(provider, success: true))
            } catch {
                await send(.providerConfigured(provider, error: error.localizedDescription))
            }

        case .configureProvider(let provider, let apiKey):
            if let providerState = state.providerStates[provider] {
                providerState.apiKey = apiKey
                return .run { send in
                    try await providerState?.configure(apiKey: apiKey)
                    await send(.providerConfigured(provider, success: true))
                } catch {
                    await send(.providerConfigured(provider, error: error.localizedDescription))
                }
            }

        case .switchProvider(let provider):
            state.selectedProvider = provider
            return .none

        case .providerConfigured(let provider, let success, let error):
            if success {
                state.providerStates[provider] = .configured
                state.errorMessages[provider] = nil
            } else {
                state.providerStates[provider] = .error
                state.errorMessages[provider] = error
            }
        }
    }
}
```

#### メリット
- **Claude Code 利用の分散**: 複数の AI サービスを並列で使用可能
- **ユーザー体験向上**: どの AI サービスでも快適に使用できる
- **コスト最適化**: キャッシを活用して API 呼び回数を最適化
- **拡張性**: 新しい AI サービスの追加が容易

#### デメリット
- **複雑性の増加**: 複数の AI サービスの管理が複雑になる
- **メンテナンスコスト**: 複数の AI サービスの管理が必要
- **実装コスト**: 複数の AI サービスの実装に時間がかかる

### 選択肢 B: 既存プロバイダーの最適化

#### 設計
```swift
// 既存プロバイダーの最適化
import ComposableArchitecture

// ストリーム処理の実装
// リクエストのバッチ化
// エラーハンドリングの改善
// キャッシの活用
```

### 選択肢 C: ダークモード対応

ユーザーが選択した「ダークモード対応」を実装します。

```swift
// ダークモードでの動作確認
enum ColorScheme {
    case light
    case dark
}

struct DarkModeState {
    var isDarkMode: Bool = false
}
```

## 実装の優先順位

### フェーズ 1: 既存環境での動作確認
1. 現在の AI サービス統合が確認
2. エラーハンドリングの現状を調査
3. Claude Code 利用状況のモニタリング

### フェーズ 2: 最適化策の実装
1. ストリーム処理の実装
2. キャッシ層の導入（Redis などは使用せず、ローカルキャッシュで十分）
3. エラーハンドリングの改善
4. API 呼び回数の最適化

### フェーズ 3: ダークモード対応
1. カラーテーマの拡張
2. 色度なトーン管理
3. 各コンポーネントのダークモード対応

## 技術的な決定事項

### Claude Code 利用の推奨
1. **モジュラー設計**: 各 AI サービスを独立したモジュールとして実装
2. **疎結合**: 各 AI サービスの通信は独立して行う
3. **エラー処理**: 各 AI サービスのエラーを個別に処理
4. **ロギング**: 各 AI サービスの通信ログを記録

### ダークモード実装
1. **カラーテーマ**: プライマリーとダークテーマの定義
2. **動的トーン**: システム設定に基づいて自動切替え
3. **コンポーネント対応**: すべての UI コンポーネントのダークモード対応

## 注意点

### 実装範囲
- **最小限の変更**: 現在のコードを壊さない範囲で実装
- **テスト優先**: 機能が動くことを確認してから実装
- **ドキュメント更新**: 変更内容を明確に記録

### リスク管理
- **複雑性の認識**: 複数の AI サービス管理は複雑であることを認識
- **段階的実装**: いきなり完全な実装を避ける
- **バックアッププラン**: エラーが発生した場合の対処方法

## 次のステップ

1. **要件確認**: 具体的な実装要件の確認
2. **設計の詳細化**: 選択肢ごとの詳細な設計計画の作成
3. **実装**: ユーザーの選択に従った対応の実装
4. **テスト**: 複数の AI サービスの連携テスト

## 現在の課題

**Claude Code 利用制限**: レート制限、トークン制限、コンテキスト制限に達している可能性
**開発環境**: Windows + macOS で並行開発が必要
**要求**: Claude Code だけでなく、複数の AI サービスを選択的に使用

この対応策を確実に実装するために、詳細な計画を立てる必要があります。
