import Foundation
import SwiftData

// MARK: - Retrieval Types

/// Retrieval のスコープを表す
enum RetrievalScope {
    case file(UUID)
    case project(UUID)
    case global
}

/// Retrieval 結果のコンテキスト
struct RetrievalContext {
    let scope: RetrievalScope
    let chunks: [RetrievedKnowledgeChunk]
    let fileSummary: String?
    let transcriptText: String?
}

// MARK: - AskAIRetrievalService

/// KnowledgeChunk ベースの retrieval service。
/// LocalRetrievalEngine を活用して query-aware なスコアリングを行い、
/// project / global scope では keyword + rankHint で top-N を返す。
/// file scope では直接コンテキスト（transcript / summary / memo / photoOCR / todo）を rank 付きで取得する。
@MainActor
final class AskAIRetrievalService {
    private let modelContext: ModelContext
    private let retrievalEngine: LocalRetrievalEngine

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.retrievalEngine = LocalRetrievalEngine(modelContext: modelContext)
    }

    // MARK: - Public API

    /// 指定スコープ・クエリで retrieval を実行し、top-N の結果を返す。
    /// file scope のみ、直接コンテキスト（transcript / summary / memo / photoOCR / todo）も併せて取得する。
    func retrieve(scope: RetrievalScope, query: String, topN: Int = 8) -> RetrievalContext {
        switch scope {
        case .file(let fileID):
            return retrieveFileScope(fileID: fileID, query: query, topN: topN)
        case .project(let projectID):
            return retrieveProjectScope(projectID: projectID, query: query, topN: topN)
        case .global:
            return retrieveGlobalScope(query: query, topN: topN)
        }
    }

    /// スコープに応じた KnowledgeChunk を rankHint 順で取得する（query なしフォールバック用）。
    func fetchRankedChunks(scope: RetrievalScope, limit: Int = 8) -> [KnowledgeChunk] {
        switch scope {
        case .file(let fileID):
            return fetchChunks(scopeType: .file, scopeID: fileID, limit: limit)
        case .project(let projectID):
            return fetchChunks(scopeType: .project, scopeID: projectID, limit: limit)
        case .global:
            return fetchChunks(scopeType: .global, scopeID: nil, limit: limit)
        }
    }

    // MARK: - File Scope

    private func retrieveFileScope(fileID: UUID, query: String, topN: Int) -> RetrievalContext {
        let file = fetchAudioFile(id: fileID)

        // query-aware retrieval
        var chunks: [RetrievedKnowledgeChunk] = []
        if let results = try? retrievalEngine.search(
            query: query,
            scope: .file,
            scopeID: fileID,
            limit: topN
        ), !results.isEmpty {
            chunks = results
        } else {
            // fallback: rankHint-based
            let rankedChunks = fetchChunks(scopeType: .file, scopeID: fileID, limit: topN)
            chunks = rankedChunks.map { chunk in
                RetrievedKnowledgeChunk(
                    chunk: chunk,
                    score: chunk.rankHint,
                    matchedTerms: []
                )
            }
        }

        return RetrievalContext(
            scope: .file(fileID),
            chunks: chunks,
            fileSummary: file?.summary,
            transcriptText: file.flatMap { fetchTranscript(for: $0.id)?.text }
        )
    }

    // MARK: - Project Scope

    private func retrieveProjectScope(projectID: UUID, query: String, topN: Int) -> RetrievalContext {
        var chunks: [RetrievedKnowledgeChunk] = []
        if let results = try? retrievalEngine.search(
            query: query,
            scope: .project,
            scopeID: projectID,
            limit: topN
        ), !results.isEmpty {
            chunks = results
        } else {
            // fallback: rankHint-based
            let rankedChunks = fetchChunks(scopeType: .project, scopeID: projectID, limit: topN)
            chunks = rankedChunks.map { chunk in
                RetrievedKnowledgeChunk(
                    chunk: chunk,
                    score: chunk.rankHint,
                    matchedTerms: []
                )
            }
        }

        return RetrievalContext(
            scope: .project(projectID),
            chunks: chunks,
            fileSummary: nil,
            transcriptText: nil
        )
    }

    // MARK: - Global Scope

    private func retrieveGlobalScope(query: String, topN: Int) -> RetrievalContext {
        var chunks: [RetrievedKnowledgeChunk] = []
        if let results = try? retrievalEngine.search(
            query: query,
            scope: .global,
            scopeID: nil,
            limit: topN
        ), !results.isEmpty {
            chunks = results
        } else {
            // fallback: rankHint-based
            let rankedChunks = fetchChunks(scopeType: .global, scopeID: nil, limit: topN)
            chunks = rankedChunks.map { chunk in
                RetrievedKnowledgeChunk(
                    chunk: chunk,
                    score: chunk.rankHint,
                    matchedTerms: []
                )
            }
        }

        return RetrievalContext(
            scope: .global,
            chunks: chunks,
            fileSummary: nil,
            transcriptText: nil
        )
    }

    // MARK: - Data Fetching

    private func fetchChunks(
        scopeType: KnowledgeChunkScopeType,
        scopeID: UUID?,
        limit: Int
    ) -> [KnowledgeChunk] {
        let scopeTypeRaw = scopeType.rawValue

        var descriptor: FetchDescriptor<KnowledgeChunk>
        if let scopeID {
            descriptor = FetchDescriptor<KnowledgeChunk>(
                predicate: #Predicate {
                    $0.scopeTypeRaw == scopeTypeRaw && $0.scopeID == scopeID
                },
                sortBy: [
                    SortDescriptor(\.rankHint, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse)
                ]
            )
        } else {
            descriptor = FetchDescriptor<KnowledgeChunk>(
                predicate: #Predicate {
                    $0.scopeTypeRaw == scopeTypeRaw
                },
                sortBy: [
                    SortDescriptor(\.rankHint, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse)
                ]
            )
        }
        descriptor.fetchLimit = limit

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAudioFile(id: UUID) -> AudioFile? {
        let descriptor = FetchDescriptor<AudioFile>()
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.id == id })
    }

    private func fetchTranscript(for fileID: UUID) -> Transcript? {
        let descriptor = FetchDescriptor<Transcript>()
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.audioFileID == fileID })
    }
}
