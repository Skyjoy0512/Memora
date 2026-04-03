import Foundation

enum OmiConnectionState: String, Sendable, CustomStringConvertible {
    case disconnected = "未接続"
    case scanning = "スキャン中"
    case connecting = "接続中"
    case connected = "接続済み"
    case importingAudio = "音声取り込み中"
    case unavailable = "SDK 未設定"

    var description: String {
        rawValue
    }
}

struct OmiDeviceDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let subtitle: String

    var stableDisplayName: String {
        name.isEmpty ? "Omi \(id.prefix(6))" : name
    }
}

struct OmiImportedAudio: Equatable, Sendable {
    let audioFileID: UUID
    let title: String
    let importedAt: Date
}
