import Foundation
import SwiftData

@Model
final class CustomSummaryTemplate {
    var id: UUID
    var name: String
    var prompt: String
    var outputSections: [String]
    var createdAt: Date

    init(name: String, prompt: String, outputSections: [String]) {
        self.id = UUID()
        self.name = name
        self.prompt = prompt
        self.outputSections = outputSections
        self.createdAt = Date()
    }
}
