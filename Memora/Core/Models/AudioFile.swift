import Foundation
import SwiftData

@Model
final class AudioFile {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var audioURL: String
    var isTranscribed: Bool = false
    var projectID: UUID?
    // 要約関連フィールド
    var isSummarized: Bool = false
    var summary: String?
    var keyPoints: String?
    var actionItems: String?


    init(title: String, audioURL: String, projectID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.audioURL = audioURL
        self.createdAt = Date()
        self.duration = 0
        self.projectID = projectID
    }
}
