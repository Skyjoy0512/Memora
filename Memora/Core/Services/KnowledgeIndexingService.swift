import Foundation
import SwiftData

struct KnowledgeChunkDraft {
    let scopeType: KnowledgeChunkScopeType
    let scopeID: UUID?
    let sourceType: KnowledgeChunkSourceType
    let sourceID: UUID?
    let text: String
    let keywords: [String]
    let rankHint: Double
}

@MainActor
final class KnowledgeIndexingService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func rebuildIndex(for audioFile: AudioFile) throws {
        let transcripts = fetchTranscripts(audioFileID: audioFile.id)
        let memos = fetchMeetingMemos(audioFileID: audioFile.id)
        let attachments = fetchPhotoAttachments(audioFileID: audioFile.id)

        let staleSources = Set(
            transcripts.map { ChunkSourceKey(type: .transcript, id: $0.id) } +
            memos.map { ChunkSourceKey(type: .memo, id: $0.id) } +
            attachments.map { ChunkSourceKey(type: .photoOCR, id: $0.id) } +
            [
                ChunkSourceKey(type: .summary, id: audioFile.id),
                ChunkSourceKey(type: .referenceTranscript, id: audioFile.id)
            ]
        )

        try deleteChunks(matching: staleSources)

        let latestTranscript = transcripts.sorted { $0.createdAt > $1.createdAt }.first
        let latestMemo = memos.sorted { $0.updatedAt > $1.updatedAt }.first

        let drafts =
            draftChunks(for: latestTranscript, audioFile: audioFile) +
            draftSummaryChunks(for: audioFile) +
            draftChunks(for: latestMemo, audioFile: audioFile) +
            draftReferenceTranscriptChunks(for: audioFile) +
            attachments.flatMap { draftPhotoOCRChunks(for: $0, audioFile: audioFile) }

        for draft in drafts {
            modelContext.insert(
                KnowledgeChunk(
                    scopeType: draft.scopeType,
                    scopeID: draft.scopeID,
                    sourceType: draft.sourceType,
                    sourceID: draft.sourceID,
                    text: draft.text,
                    keywords: draft.keywords,
                    rankHint: draft.rankHint
                )
            )
        }

        if !drafts.isEmpty || !staleSources.isEmpty {
            try modelContext.save()
        }
    }

    func removeChunks(sourceType: KnowledgeChunkSourceType, sourceID: UUID, autosave: Bool = true) throws {
        try deleteChunks(matching: Set([ChunkSourceKey(type: sourceType, id: sourceID)]))
        if autosave {
            try modelContext.save()
        }
    }

    func draftChunks(
        text: String,
        sourceType: KnowledgeChunkSourceType,
        sourceID: UUID?,
        audioFile: AudioFile,
        baseRank: Double
    ) -> [KnowledgeChunkDraft] {
        guard let normalizedText = Self.normalizedIndexableText(text), !normalizedText.isEmpty else { return [] }

        let scopes = scopeTargets(for: audioFile)
        let segments = Self.chunkText(normalizedText)

        return scopes.flatMap { scope in
            segments.enumerated().map { offset, segment in
                KnowledgeChunkDraft(
                    scopeType: scope.scopeType,
                    scopeID: scope.scopeID,
                    sourceType: sourceType,
                    sourceID: sourceID,
                    text: segment,
                    keywords: Self.extractKeywords(from: segment),
                    rankHint: max(0, baseRank - Double(offset) * 0.015)
                )
            }
        }
    }

    private func draftChunks(for transcript: Transcript?, audioFile: AudioFile) -> [KnowledgeChunkDraft] {
        guard let transcript else { return [] }
        return draftChunks(
            text: transcript.text,
            sourceType: .transcript,
            sourceID: transcript.id,
            audioFile: audioFile,
            baseRank: 0.88
        )
    }

    private func draftChunks(for memo: MeetingMemo?, audioFile: AudioFile) -> [KnowledgeChunkDraft] {
        guard let memo else { return [] }
        return draftChunks(
            text: memo.plainTextCache,
            sourceType: .memo,
            sourceID: memo.id,
            audioFile: audioFile,
            baseRank: 0.93
        )
    }

    private func draftSummaryChunks(for audioFile: AudioFile) -> [KnowledgeChunkDraft] {
        let summaryLines = [
            Self.normalizedIndexableText(audioFile.summary),
            Self.normalizedIndexableText(audioFile.keyPoints),
            Self.normalizedIndexableText(audioFile.actionItems)
        ].compactMap { $0 }

        guard !summaryLines.isEmpty else { return [] }

        return draftChunks(
            text: summaryLines.joined(separator: "\n\n"),
            sourceType: .summary,
            sourceID: audioFile.id,
            audioFile: audioFile,
            baseRank: 1.0
        )
    }

    private func draftReferenceTranscriptChunks(for audioFile: AudioFile) -> [KnowledgeChunkDraft] {
        draftChunks(
            text: audioFile.referenceTranscript ?? "",
            sourceType: .referenceTranscript,
            sourceID: audioFile.id,
            audioFile: audioFile,
            baseRank: 0.72
        )
    }

    private func draftPhotoOCRChunks(for attachment: PhotoAttachment, audioFile: AudioFile) -> [KnowledgeChunkDraft] {
        let components = [
            Self.normalizedIndexableText(attachment.caption),
            Self.normalizedIndexableText(attachment.ocrText)
        ].compactMap { $0 }

        guard !components.isEmpty else { return [] }

        return draftChunks(
            text: components.joined(separator: "\n"),
            sourceType: .photoOCR,
            sourceID: attachment.id,
            audioFile: audioFile,
            baseRank: 0.8
        )
    }

    private func fetchTranscripts(audioFileID: UUID) -> [Transcript] {
        var descriptor = FetchDescriptor<Transcript>(
            predicate: #Predicate { $0.audioFileID == audioFileID }
        )
        descriptor.fetchLimit = 10
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchMeetingMemos(audioFileID: UUID) -> [MeetingMemo] {
        var descriptor = FetchDescriptor<MeetingMemo>(
            predicate: #Predicate { $0.audioFileID == audioFileID }
        )
        descriptor.fetchLimit = 10
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPhotoAttachments(audioFileID: UUID) -> [PhotoAttachment] {
        let ownerTypeRaw = PhotoAttachmentOwnerType.audioFile.rawValue
        var descriptor = FetchDescriptor<PhotoAttachment>(
            predicate: #Predicate {
                $0.ownerTypeRaw == ownerTypeRaw &&
                $0.ownerID == audioFileID
            }
        )
        descriptor.fetchLimit = 200
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteChunks(matching sources: Set<ChunkSourceKey>) throws {
        guard !sources.isEmpty else { return }

        let allChunks = try modelContext.fetch(FetchDescriptor<KnowledgeChunk>())
        for chunk in allChunks {
            let key = ChunkSourceKey(type: chunk.sourceType, id: chunk.sourceID)
            if sources.contains(key) {
                modelContext.delete(chunk)
            }
        }
    }

    private func scopeTargets(for audioFile: AudioFile) -> [(scopeType: KnowledgeChunkScopeType, scopeID: UUID?)] {
        var scopes: [(KnowledgeChunkScopeType, UUID?)] = [(.file, audioFile.id)]
        if let projectID = audioFile.projectID {
            scopes.append((.project, projectID))
        }
        scopes.append((.global, nil))
        return scopes
    }

    nonisolated static func chunkText(_ text: String, targetLength: Int = 220, hardLimit: Int = 320) -> [String] {
        guard let normalized = normalizedIndexableText(text), !normalized.isEmpty else { return [] }

        let sentences = sentenceUnits(from: normalized)
        guard !sentences.isEmpty else { return [normalized] }

        var chunks: [String] = []
        var buffer = ""

        func flushBuffer() {
            let trimmed = normalizedIndexableText(buffer)
            if let trimmed, !trimmed.isEmpty {
                chunks.append(trimmed)
            }
            buffer = ""
        }

        for sentence in sentences {
            if buffer.isEmpty {
                if sentence.count > hardLimit {
                    chunks.append(contentsOf: hardWrappedChunks(sentence, maxLength: hardLimit))
                } else {
                    buffer = sentence
                }
                continue
            }

            let candidate = buffer + " " + sentence
            if candidate.count <= targetLength {
                buffer = candidate
            } else {
                flushBuffer()
                if sentence.count > hardLimit {
                    chunks.append(contentsOf: hardWrappedChunks(sentence, maxLength: hardLimit))
                } else {
                    buffer = sentence
                }
            }
        }

        flushBuffer()
        return chunks
    }

    nonisolated static func extractKeywords(from text: String, limit: Int = 8) -> [String] {
        guard let normalized = normalizedIndexableText(text) else { return [] }

        let pattern = #"[A-Za-z0-9][A-Za-z0-9_-]{1,}|[一-龠々ぁ-んァ-ヶー]{2,}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(normalized.startIndex..., in: normalized)

        var seen: Set<String> = []
        var keywords: [String] = []

        regex?.enumerateMatches(in: normalized, range: range) { match, _, stop in
            guard
                let match,
                let matchRange = Range(match.range, in: normalized)
            else {
                return
            }

            let token = String(normalized[matchRange]).lowercased()
            if Self.stopWords.contains(token) || seen.contains(token) {
                return
            }

            seen.insert(token)
            keywords.append(token)

            if keywords.count >= limit {
                stop.pointee = true
            }
        }

        return keywords
    }

    nonisolated static func normalizedIndexableText(_ text: String?) -> String? {
        guard let text else { return nil }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }

    private nonisolated static func sentenceUnits(from text: String) -> [String] {
        var units: [String] = []
        var buffer = ""
        let delimiters: Set<Character> = ["。", "！", "？", ".", "!", "?", "\n"]

        for character in text {
            buffer.append(character)
            if delimiters.contains(character) {
                let normalized = normalizedIndexableText(buffer)
                if let normalized, !normalized.isEmpty {
                    units.append(normalized)
                }
                buffer = ""
            }
        }

        if let normalized = normalizedIndexableText(buffer), !normalized.isEmpty {
            units.append(normalized)
        }

        return units
    }

    private nonisolated static func hardWrappedChunks(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var chunks: [String] = []
        var start = text.startIndex

        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex
            let part = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty {
                chunks.append(part)
            }
            start = end
        }

        return chunks
    }

    private struct ChunkSourceKey: Hashable {
        let type: KnowledgeChunkSourceType
        let id: UUID?
    }

    private nonisolated static let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "into",
        "です", "ます", "した", "する", "いる", "ある", "こと", "ため", "について"
    ]
}
