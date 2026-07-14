import Foundation

enum ConnectionTier: Int, Sendable {
    case bleDirect = 0
    case cloudSync = 1
    case fileImport = 2
}

typealias ImportSink = @MainActor @Sendable (_ audioURL: URL, _ title: String?) async throws -> AudioFile

struct CaptureDevice: Identifiable, Sendable, Hashable {
    let id: String
    let displayName: String
    let sourceType: SourceType
    let tier: ConnectionTier
    var batteryLevel: Int?
    var isAvailable: Bool

    init(
        id: String,
        displayName: String,
        sourceType: SourceType,
        tier: ConnectionTier,
        batteryLevel: Int? = nil,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceType = sourceType
        self.tier = tier
        self.batteryLevel = batteryLevel
        self.isAvailable = isAvailable
    }
}

enum CaptureConnectionState: Sendable, Equatable {
    case unavailable
    case idle
    case discovering
    case connecting
    case connected
    case syncing
    case error(String)
}
