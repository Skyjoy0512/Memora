import Foundation
import SwiftData

public enum KnowledgeChunkScopeType: String, CaseIterable {
    case file = "file"
    case project = "project"
    case global = "global"
}

public enum KnowledgeChunkSourceType: String, CaseIterable {
    case transcript = "transcript"
    case summary = "summary"
    case memo = "memo"
    case todo = "todo"
    case photoOCR = "photoOCR"
    case referenceTranscript = "referenceTranscript"
}

@Model
public final class KnowledgeChunk {
    public var id: UUID
    public var scopeTypeRaw: String
    public var scopeID: UUID?
    public var sourceTypeRaw: String
    public var sourceID: UUID?
    public var audioFile: AudioFile?
    public var text: String
    public var keywords: [String]
    public var rankHint: Double
    public var createdAt: Date
    public var updatedAt: Date

    public var scopeType: KnowledgeChunkScopeType {
        get { KnowledgeChunkScopeType(rawValue: scopeTypeRaw) ?? .file }
        set { scopeTypeRaw = newValue.rawValue }
    }

    public var sourceType: KnowledgeChunkSourceType {
        get { KnowledgeChunkSourceType(rawValue: sourceTypeRaw) ?? .transcript }
        set { sourceTypeRaw = newValue.rawValue }
    }

    public init(
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

    public func updateText(_ text: String, keywords: [String]? = nil, rankHint: Double? = nil) {
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
