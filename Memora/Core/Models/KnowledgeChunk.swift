import Foundation
import SwiftData

enum KnowledgeChunkScopeType: String, CaseIterable {
    case file = "file"
    case project = "project"
    case global = "global"
}

enum KnowledgeChunkSourceType: String, CaseIterable {
    case transcript = "transcript"
    case summary = "summary"
    case memo = "memo"
    case todo = "todo"
    case photoOCR = "photoOCR"
    case referenceTranscript = "referenceTranscript"
}

@Model
final class KnowledgeChunk {
    var id: UUID
    var scopeTypeRaw: String
    var scopeID: UUID?
    var sourceTypeRaw: String
    var sourceID: UUID?
    var text: String
    var keywords: [String]
    var rankHint: Double
    var createdAt: Date
    var updatedAt: Date

    var scopeType: KnowledgeChunkScopeType {
        get { KnowledgeChunkScopeType(rawValue: scopeTypeRaw) ?? .file }
        set { scopeTypeRaw = newValue.rawValue }
    }

    var sourceType: KnowledgeChunkSourceType {
        get { KnowledgeChunkSourceType(rawValue: sourceTypeRaw) ?? .transcript }
        set { sourceTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        scopeType: KnowledgeChunkScopeType,
        scopeID: UUID? = nil,
        sourceType: KnowledgeChunkSourceType,
        sourceID: UUID? = nil,
        text: String,
        keywords: [String] = [],
        rankHint: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.scopeTypeRaw = scopeType.rawValue
        self.scopeID = scopeID
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceID = sourceID
        self.text = text
        self.keywords = keywords
        self.rankHint = rankHint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func updateText(_ text: String, keywords: [String]? = nil, rankHint: Double? = nil) {
        self.text = text
        if let keywords {
            self.keywords = keywords
        }
        if let rankHint {
            self.rankHint = rankHint
        }
        self.updatedAt = Date()
    }
}
