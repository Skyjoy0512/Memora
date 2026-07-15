import Foundation
import SwiftData

@Model
public final class BotMeetingConfig {
    public var serverURL: String = ""
    public var apiKey: String = ""
    public var isEnabled: Bool = false
    public var defaultPlatform: String = "google_meet"
    public var createdAt: Date
    public var updatedAt: Date

    public init() {
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
