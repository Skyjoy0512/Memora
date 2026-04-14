import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// オンデバイス LLM モデルの管理状態を提供するサービス。
/// model download / availability / memory requirement を管理する。
@MainActor
final class ModelStoreService: ObservableObject {

    // MARK: - Published State

    /// Foundation Models フレームワークがコンパイル時に存在するか
    @Published private(set) var isFrameworkAvailable: Bool = false

    /// Foundation Models がランタイムで利用可能か
    @Published private(set) var isFoundationModelsAvailable: Bool = false

    /// デバイスがローカル推論要件を満たすか
    @Published private(set) var isDeviceSupported: Bool = false

    /// オンデバイスモデルがダウンロード済みで即座に利用可能か
    @Published private(set) var isModelReady: Bool = false

    /// ステータス説明テキスト
    @Published private(set) var statusDescription: String = "確認中..."

    // MARK: - Init

    init() {
        checkAvailability()
    }

    // MARK: - Public

    func refresh() {
        checkAvailability()
    }

    /// モデルを事前ロードして初回応答のレイテンシを削減する
    func prewarm() async {
        guard isModelReady else { return }
        let provider = LocalLLMProvider()
        await provider.prewarm()
    }

    // MARK: - Private

    private func checkAvailability() {
        // Framework availability
        isFrameworkAvailable = LocalLLMProvider.isFrameworkAvailable

        // iOS version + framework check
        isFoundationModelsAvailable = LocalLLMProvider.isAvailable

        // Device support check (Apple Silicon required for Foundation Models)
        isDeviceSupported = isAppleSiliconDevice()

        // Model download / readiness check
        checkModelReadiness()

        // Status description
        updateStatusDescription()
    }

    private func checkModelReadiness() {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            switch SystemLanguageModel.default.availability {
            case .available:
                isModelReady = true
            case .unavailable:
                isModelReady = false
            }
            #else
            isModelReady = false
            #endif
        } else {
            isModelReady = false
        }
    }

    private func updateStatusDescription() {
        if !isDeviceSupported {
            statusDescription = "このデバイスはオンデバイス AI をサポートしていません（A17 Pro / M1 以降が必要）"
        } else if !isFoundationModelsAvailable {
            statusDescription = "iOS 26 以降が必要です"
        } else if !isModelReady {
            statusDescription = "モデルのダウンロード待ちです（設定アプリで確認してください）"
        } else {
            statusDescription = "オンデバイス AI が利用可能です"
        }
    }

    private func isAppleSiliconDevice() -> Bool {
        // All modern iPhones (A9+) support Neural Engine.
        // Foundation Models requires A17 Pro / M1 or later.
        // ProcessInfo doesn't expose chip info directly, so we use
        // memory threshold as a proxy: devices with < 6GB RAM are unlikely to run on-device LLM.
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let sixGB: UInt64 = 6 * 1024 * 1024 * 1024
        return physicalMemory >= sixGB
    }
}
