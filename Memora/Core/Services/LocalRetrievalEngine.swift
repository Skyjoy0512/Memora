import Foundation
import SwiftData

struct RetrievalScore {
    let score: Double
    let matchedTerms: [String]
}

struct RetrievedKnowledgeChunk {
    let chunk: KnowledgeChunk
    let score: Double
    let matchedTerms: [String]
}

@MainActor
final class LocalRetrievalEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func search(
        query: String,
        scope: KnowledgeChunkScopeType,
        scopeID: UUID?,
        limit: Int = 8
    ) throws -> [RetrievedKnowledgeChunk] {
        let allChunks = try modelContext.fetch(FetchDescriptor<KnowledgeChunk>())
        let scopedChunks = allChunks.filter {
            $0.scopeType == scope &&
            $0.scopeID == scopeID
        }

        let memoryBoostTerms = fetchMemoryBoostTerms(query: query)

        let results = scopedChunks
            .map { chunk in
                let retrievalScore = Self.score(query: query, for: chunk)
                var finalScore = retrievalScore.score

                let text = chunk.text.lowercased()
                for term in memoryBoostTerms where text.contains(term) {
                    finalScore += 0.15
                }

                return RetrievedKnowledgeChunk(
                    chunk: chunk,
                    score: finalScore,
                    matchedTerms: retrievalScore.matchedTerms
                )
            }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score {
                    return $0.chunk.updatedAt > $1.chunk.updatedAt
                }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }

        return results
    }

    nonisolated static func score(query: String, for chunk: KnowledgeChunk) -> RetrievalScore {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let queryTerms = KnowledgeIndexingService.extractKeywords(from: normalizedQuery, limit: 12)
        let haystack = chunk.text.lowercased()
        let keywordSet = Set(chunk.keywords.map { $0.lowercased() })

        guard !normalizedQuery.isEmpty else {
            return RetrievalScore(score: max(0.01, chunk.rankHint), matchedTerms: [])
        }

        var score = max(0, chunk.rankHint) * 0.35
        var matchedTerms: [String] = []

        if haystack.contains(normalizedQuery) {
            score += 1.2
        }

        for term in queryTerms {
            if keywordSet.contains(term) {
                matchedTerms.append(term)
                score += 0.75
            } else if haystack.contains(term) {
                matchedTerms.append(term)
                score += 0.35
            }
        }

        let uniqueTerms = Array(Set(matchedTerms))
        if !queryTerms.isEmpty {
            score += Double(uniqueTerms.count) / Double(queryTerms.count) * 0.7
        }

        switch chunk.sourceType {
        case .summary:
            score += 0.08
        case .memo:
            score += 0.05
        case .photoOCR:
            score -= 0.03
        case .transcript, .todo, .referenceTranscript:
            break
        }

        return RetrievalScore(score: score, matchedTerms: uniqueTerms.sorted())
    }

    // MARK: - Memory Boost

    /// 承認済み MemoryFact の value を小文字化して返す。
    /// クエリに含まれる用語が fact の value と一致すれば、その fact に関連するチャンクをブーストする。
    private func fetchMemoryBoostTerms(query: String) -> [String] {
        let privacyMode = UserDefaults.standard.string(forKey: "memoryPrivacyMode") ?? "standard"
        guard privacyMode != "off" else { return [] }

        let descriptor = FetchDescriptor<MemoryFact>(
            predicate: #Predicate { $0.lastConfirmedAt != nil }
        )
        let confirmedFacts = (try? modelContext.fetch(descriptor)) ?? []

        let disabledIDs = Set(
            (UserDefaults.standard.stringArray(forKey: "disabledMemoryFactIDs") ?? [])
                .compactMap(UUID.init(uuidString:))
        )

        let lowerQuery = query.lowercased()
        return confirmedFacts
            .filter { !disabledIDs.contains($0.id) }
            .map { $0.value.lowercased() }
            .filter { value in
                !value.isEmpty && lowerQuery.contains(value)
            }
    }
}
