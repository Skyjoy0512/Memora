import Foundation
import SwiftData
internal import MemoraNative
import MemoraSharedAskAI
import MemoraSharedCore
import MemoraSharedSchema

enum MemoraKnowledgeQueryError: LocalizedError {
  case invalidScope, targetNotFound, apiKeyMissing, providerUnavailable, generationFailed, saveFailed
  var errorDescription: String? {
    switch self {
    case .invalidScope: return "質問対象を識別できません。"
    case .targetNotFound: return "質問対象が見つかりません。"
    case .apiKeyMissing: return "選択したプロバイダーのAPIキーが設定されていません。"
    case .providerUnavailable: return "選択したプロバイダーは利用できません。"
    case .generationFailed: return "回答の生成に失敗しました。時間をおいてもう一度お試しください。"
    case .saveFailed: return "会話を保存できませんでした。"
    }
  }
}

@MainActor
final class MemoraSharedStoreKnowledgeQuery: MemoraKnowledgeQuerying {
  let sourceDescription = "swiftdata"
  private let container: ModelContainer
  private let credentials = MemoraRNKeychainSecureCredentials()

  init(container: ModelContainer) { self.container = container }

  func queryKnowledge(_ request: MemoraKnowledgeQueryRequestDTO) async throws -> MemoraKnowledgeQueryResponseDTO {
    let context = ModelContext(container)
    let scope: ChatScope
    let scopeType: AskAIScopeType
    let scopeID: UUID?
    switch request.scope {
    case "global": scope = .global; scopeType = .global; scopeID = nil
    case "file":
      guard let id = request.audioFileId.flatMap(UUID.init(uuidString:)) else { throw MemoraKnowledgeQueryError.invalidScope }
      guard (try? context.fetch(FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == id })).first) != nil else { throw MemoraKnowledgeQueryError.targetNotFound }
      scope = .file(fileId: id); scopeType = .file; scopeID = id
    case "project":
      guard let id = request.projectId.flatMap(UUID.init(uuidString:)) else { throw MemoraKnowledgeQueryError.invalidScope }
      guard (try? context.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })).first) != nil else { throw MemoraKnowledgeQueryError.targetNotFound }
      scope = .project(projectId: id); scopeType = .project; scopeID = id
    default: throw MemoraKnowledgeQueryError.invalidScope
    }

    let core = KnowledgeQueryCore(modelContext: context, memoryPrivacy: .init(mode: "standard", disabledFactIDs: []))
    let pack = core.buildContext(for: scope, query: request.question)
    let prompt = core.makePrompt(userMessage: request.question, contextPack: pack)
    // Provider selection is intentionally host-local; no credential crosses this boundary.
    guard let key = try credentials.apiKey(for: .openAI), !key.isEmpty else { throw MemoraKnowledgeQueryError.apiKeyMissing }
    let provider: any LLMProvider
    do { provider = try MemoraRNRemoteLLMProvider.make(provider: .openAI, apiKey: key) } catch { throw MemoraKnowledgeQueryError.providerUnavailable }
    let answer: String
    do { answer = try await provider.summarize(transcript: prompt).summary.trimmingCharacters(in: .whitespacesAndNewlines) } catch { throw MemoraKnowledgeQueryError.generationFailed }
    let sessionID = UUID(uuidString: request.sessionId ?? "") ?? UUID()
    let session = AskAISession(id: sessionID, scopeType: scopeType, scopeID: scopeID, title: String(request.question.prefix(40)))
    context.insert(session)
    context.insert(AskAIMessage(sessionID: sessionID, role: .user, content: request.question))
    context.insert(AskAIMessage(sessionID: sessionID, role: .assistant, content: answer))
    do { try context.save() } catch { throw MemoraKnowledgeQueryError.saveFailed }
    return MemoraKnowledgeQueryResponseDTO(id: UUID().uuidString, answer: answer, sources: pack.citations.map(\.title), scope: request.scope, answeredAt: Date(), sessionId: sessionID.uuidString)
  }
}
