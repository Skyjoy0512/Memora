import Foundation

/// オンデバイス LLM モデルの管理状態を提供するサービス。
/// model download / availability / memory requirement を管理する。
@MainActor
final class ModelStoreService: ObservableObject {

    // MARK: - Published State

    /// Foundation Models が利用可能か
    @Published private(set) var isFoundationModelsAvailable: Bool = false

    /// デバイスがローカル推論要件を満たすか
    @Published private(set) var isDeviceSupported: Bool = false

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

    // MARK: - Private

    private func checkAvailability() {
        // iOS version check
        if #available(iOS 26.0, *) {
            isFoundationModelsAvailable = LocalLLMProvider.isAvailable
        } else {
            isFoundationModelsAvailable = false
        }

        // Device support check (Apple Silicon required for Foundation Models)
        isDeviceSupported = isAppleSiliconDevice()

        // Status description
        if !isDeviceSupported {
            statusDescription = "このデバイスはオンデバイス AI をサポートしていません"
        } else if isFoundationModelsAvailable {
            statusDescription = "オンデバイス AI が利用可能です"
        } else {
            statusDescription = "iOS 26 以降が必要です"
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
