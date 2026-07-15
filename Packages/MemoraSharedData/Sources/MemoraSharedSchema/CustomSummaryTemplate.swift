import Foundation
import SwiftData

@Model
public final class CustomSummaryTemplate {
    public var id: UUID
    public var name: String
    public var prompt: String
    public var outputSections: [String]
    public var createdAt: Date

    public init(name: String, prompt: String, outputSections: [String]) {
        self.id = UUID()
        self.name = name
        self.prompt = prompt
        self.outputSections = outputSections
        self.createdAt = Date()
    }
}
