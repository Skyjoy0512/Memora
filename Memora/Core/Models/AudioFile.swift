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

    init(title: String, audioURL: String, projectID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.audioURL = audioURL
        self.createdAt = Date()
        self.duration = 0
        self.projectID = projectID
    }
}
