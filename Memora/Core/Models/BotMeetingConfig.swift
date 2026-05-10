import Foundation
import SwiftData

@Model
final class BotMeetingConfig {
    var serverURL: String = ""
    var apiKey: String = ""
    var isEnabled: Bool = false
    var defaultPlatform: String = "google_meet"
    var createdAt: Date
    var updatedAt: Date

    init() {
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
