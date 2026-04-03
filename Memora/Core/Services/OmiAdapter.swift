import Foundation

#if canImport(omi_lib)
import omi_lib
#endif

@MainActor
final class OmiAdapter: ObservableObject {
    typealias AudioImportHandler = @Sendable (URL, String?) async throws -> OmiImportedAudio

    @Published private(set) var discoveredDevices: [OmiDeviceDescriptor] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isConnected = false
    @Published private(set) var isImportingAudio = false
    @Published private(set) var connectionState: OmiConnectionState = sdkAvailable ? .disconnected : .unavailable
    @Published private(set) var previewTranscript = ""
    @Published private(set) var lastImportedAudio: OmiImportedAudio?
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    static let sdkAvailable: Bool = {
        #if canImport(omi_lib)
        true
        #else
        false
        #endif
    }()

    var sdkAvailable: Bool {
        Self.sdkAvailable
    }

    var connectedDeviceName: String? {
        connectedDevice?.stableDisplayName
    }

    var sessionTerminationDescription: String {
        "「セッション終了」は Memora 側の preview / audio import を停止します。物理接続の終了可否は Omi SDK の公開 API に依存します。"
    }

    private var connectedDevice: OmiDeviceDescriptor?
    private var audioImportHandler: AudioImportHandler?
    private var previewChunks: [String] = []
    private var scanSessionID = UUID()
    private var connectionSessionID = UUID()
    #if canImport(omi_lib)
    private var scannedDevices: [String: Device] = [:]
    #endif

    func configureAudioImportHandler(_ handler: @escaping AudioImportHandler) {
        audioImportHandler = handler
    }

    func startScan() {
        guard sdkAvailable else {
            connectionState = .unavailable
            errorMessage = "Omi Swift SDK が未導入です。project.yml の package 追加後に xcodegen を再生成してください。"
            return
        }

        scanSessionID = UUID()
        discoveredDevices.removeAll()
        #if canImport(omi_lib)
        scannedDevices.removeAll()
        #endif
        errorMessage = nil
        statusMessage = nil
        isScanning = true
        connectionState = .scanning

        #if canImport(omi_lib)
        let sessionID = scanSessionID
        OmiManager.startScan { [weak self] device, error in
            Task { @MainActor [weak self] in
                guard let self, self.scanSessionID == sessionID else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                    self.connectionState = .disconnected
                    return
                }

                guard let device else { return }
                let descriptor = self.makeDescriptor(from: device)
                self.scannedDevices[descriptor.id] = device
                if !self.discoveredDevices.contains(where: { $0.id == descriptor.id }) {
                    self.discoveredDevices.append(descriptor)
                }
            }
        }
        #endif
    }

    func stopScan() {
        scanSessionID = UUID()
        isScanning = false

        #if canImport(omi_lib)
        OmiManager.endScan()
        #endif

        if !isConnected {
            connectionState = sdkAvailable ? .disconnected : .unavailable
        }
    }

    func connect(to descriptor: OmiDeviceDescriptor) {
        guard sdkAvailable else {
            connectionState = .unavailable
            errorMessage = "Omi Swift SDK が未導入です。"
            return
        }

        stopScan()
        previewChunks.removeAll()
        previewTranscript = ""
        lastImportedAudio = nil
        errorMessage = nil
        statusMessage = nil
        connectedDevice = descriptor
        isConnected = false
        connectionState = .connecting
        connectionSessionID = UUID()

        #if canImport(omi_lib)
        guard let device = scannedDevices[descriptor.id] else {
            errorMessage = "スキャン済みの Omi デバイス情報が見つかりません"
            connectionState = .disconnected
            return
        }
        observeConnection(for: descriptor, sessionID: connectionSessionID)
        OmiManager.connectToDevice(device: device)
        #endif
    }

    func disconnect() {
        connectionSessionID = UUID()
        stopScan()
        isConnected = false
        isImportingAudio = false
        connectedDevice = nil
        previewChunks.removeAll()
        previewTranscript = ""
        connectionState = sdkAvailable ? .disconnected : .unavailable
        statusMessage = sdkAvailable ? "Memora 側の Omi セッションを終了しました" : nil
        errorMessage = nil
    }

    private func observeConnection(for descriptor: OmiDeviceDescriptor, sessionID: UUID) {
        #if canImport(omi_lib)
        OmiManager.connectionUpdated { [weak self] connected in
            Task { @MainActor [weak self] in
                guard let self, self.connectionSessionID == sessionID else { return }

                self.isConnected = connected
                self.connectionState = connected ? .connected : .disconnected
                self.statusMessage = connected
                    ? "\(descriptor.stableDisplayName) の preview セッションを開始しました"
                    : "\(descriptor.stableDisplayName) との接続が切れました"

                guard connected else { return }
                self.startPreviewStreams(for: descriptor, sessionID: sessionID)
            }
        }
        #endif
    }

    private func startPreviewStreams(for descriptor: OmiDeviceDescriptor, sessionID: UUID) {
        #if canImport(omi_lib)
        guard let device = scannedDevices[descriptor.id] else {
            errorMessage = "接続中の Omi デバイス情報を復元できません"
            return
        }

        OmiManager.getLiveTranscription(device: device) { [weak self] transcript in
            Task { @MainActor [weak self] in
                guard let self, self.connectionSessionID == sessionID else { return }
                self.consumePreviewTranscript(transcript)
            }
        }

        OmiManager.getLiveAudio(device: device) { [weak self] fileURL in
            Task { @MainActor [weak self] in
                guard let self, self.connectionSessionID == sessionID else { return }
                guard let fileURL else { return }
                await self.importLiveAudio(fileURL, from: descriptor)
            }
        }
        #endif
    }

    private func consumePreviewTranscript(_ transcript: String?) {
        guard let transcript else { return }
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if previewChunks.last != trimmed {
            previewChunks.append(trimmed)
            if previewChunks.count > 6 {
                previewChunks.removeFirst(previewChunks.count - 6)
            }
            previewTranscript = previewChunks.joined(separator: "\n")
        }
    }

    private func importLiveAudio(_ fileURL: URL, from descriptor: OmiDeviceDescriptor) async {
        guard let audioImportHandler else {
            errorMessage = "Omi 音声 importer が未設定です"
            return
        }

        isImportingAudio = true
        connectionState = .importingAudio

        do {
            let title = omiImportTitle(for: descriptor)
            let importedAudio = try await audioImportHandler(fileURL, title)
            lastImportedAudio = importedAudio
            statusMessage = "\(importedAudio.title) を Memora に取り込みました"
            connectionState = isConnected ? .connected : .disconnected
        } catch {
            errorMessage = "Omi 音声の取り込みに失敗しました: \(error.localizedDescription)"
            connectionState = isConnected ? .connected : .disconnected
        }

        isImportingAudio = false
    }

    #if canImport(omi_lib)
    private func makeDescriptor(from device: Device) -> OmiDeviceDescriptor {
        let shortID = String(device.id.prefix(6))
        return OmiDeviceDescriptor(
            id: device.id,
            name: "Omi \(shortID)",
            subtitle: device.id
        )
    }
    #endif

    private func omiImportTitle(for descriptor: OmiDeviceDescriptor) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(descriptor.stableDisplayName) \(formatter.string(from: Date()))"
    }
}
