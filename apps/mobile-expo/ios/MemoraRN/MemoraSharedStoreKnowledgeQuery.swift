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

  /// モデル入力へ含める履歴の上限。RN 側 askAiLogic の ASK_AI_HISTORY_MAX_MESSAGES /
  /// ASK_AI_HISTORY_MAX_CONTENT_LENGTH と値を揃え、過剰な履歴でトークンが肥大しないようにする。
  private enum HistoryLimit {
    static let maxMessages = 6
    static let maxContentLengthPerMessage = 800
  }

  private let container: ModelContainer
  private let keyReader: any MemoraRNSummaryKeyReading
  private let providerFactory: (MemoraRNSummaryProvider, String) throws -> any LLMProvider

  init(
    container: ModelContainer,
    keyReader: any MemoraRNSummaryKeyReading = MemoraRNKeychainSecureCredentials(),
    providerFactory: @escaping (MemoraRNSummaryProvider, String) throws -> any LLMProvider = MemoraRNRemoteLLMProvider.make
  ) {
    self.container = container
    self.keyReader = keyReader
    self.providerFactory = providerFactory
  }

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
    // file スコープでは、現在アクティブなメモストア（MemoraNativeMemoRegistry が指す
    // Documents/JSON のメモ等）から対象 audioFile のユーザーメモを読み、
    // 「ユーザーメモ」として参照コンテキストへ含める。
    // RN のメモは SwiftData の MeetingMemo へ保存されないため、ここで明示的に読む必要がある。
    let userMemo = Self.currentUserMemoText(scopeType: scopeType, audioFileID: scopeID)
    let pack = core.buildContext(for: scope, query: request.question, userMemo: userMemo)

    // 既存セッションの解決（R15）:
    // - sessionId が渡され、その AskAISession が存在し、スコープ種別が一致すれば再利用して
    //   永続メッセージを履歴として読む（追記保存）。
    // - それ以外（未指定 / 不明なID / スコープ不一致）は新規作成して従来互換を保つ。
    // RN の AskAIScreen は対象スコープ（file/project/global）ごとに会話を保持しており、
    // 同一スコープ内で対象ID（audioFileId/projectId）が変わっても同じスレッドとして続けるため、
    // 再利用の判定は scopeType の一致のみで行い scopeID は照合しない。
    let requestedSessionID = request.sessionId.flatMap(UUID.init(uuidString:))
    let existingSession = requestedSessionID.flatMap { Self.fetchSession(id: $0, in: context) }
    let session: AskAISession
    var historyMessages: [AskAIMessage] = []
    if let existingSession, existingSession.scopeTypeRaw == scopeType.rawValue {
      session = existingSession
      session.updatedAt = Date()
      historyMessages = Self.fetchRecentMessages(sessionID: session.id, limit: HistoryLimit.maxMessages, in: context)
    } else {
      // 既存IDと衝突する場合（スコープ不一致で再利用しないケース）は新規UUIDを採番する。
      let newSessionID = requestedSessionID != nil && existingSession == nil ? requestedSessionID! : UUID()
      session = AskAISession(id: newSessionID, scopeType: scopeType, scopeID: scopeID, title: String(request.question.prefix(40)))
      context.insert(session)
    }

    // 永続メッセージは「モデル入力へ含める履歴」と「保存された会話」の二役を担う。
    // 直近のやり取りをコンテキスト末尾（質問の直前）へ追加し、追質問に前回答が伝わるようにする。
    let prompt: String
    if historyMessages.isEmpty {
      prompt = core.makePrompt(userMessage: request.question, contextPack: pack)
    } else {
      let historyContext = Self.makeHistoryContext(historyMessages)
      let combinedContext = pack.promptContext.isEmpty
        ? historyContext
        : pack.promptContext + "\n\n" + historyContext
      let packWithHistory = KnowledgeQueryCore.NeutralContextPack(
        scopeTitle: pack.scopeTitle,
        promptContext: combinedContext,
        citations: pack.citations,
        instructionHints: pack.instructionHints
      )
      prompt = core.makePrompt(userMessage: request.question, contextPack: packWithHistory)
    }

    // Provider selection is intentionally host-local; no credential crosses this boundary.
    guard let key = try keyReader.apiKey(for: .openAI), !key.isEmpty else { throw MemoraKnowledgeQueryError.apiKeyMissing }
    let provider: any LLMProvider
    do { provider = try providerFactory(.openAI, key) } catch { throw MemoraKnowledgeQueryError.providerUnavailable }
    let answer: String
    do {
      // Ask AI の回答は会議要約 API（summarize）ではなく平文の回答生成 API（generate）を使う。
      // 質問＋コンテキストは makePrompt が組み立てた回答プロンプトのまま渡し、
      // 要約メタデータ（title/summary/keyPoints/actionItems）抽出の指示を混ぜない。
      answer = try await provider.generate(prompt).trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      throw MemoraKnowledgeQueryError.generationFailed
    }

    // 既存セッションへ追記 / 新規セッションへの初回保存。
    context.insert(AskAIMessage(sessionID: session.id, role: .user, content: request.question))
    context.insert(AskAIMessage(sessionID: session.id, role: .assistant, content: answer))
    do { try context.save() } catch { throw MemoraKnowledgeQueryError.saveFailed }
    return MemoraKnowledgeQueryResponseDTO(id: UUID().uuidString, answer: answer, sources: pack.citations.map(\.title), scope: request.scope, answeredAt: Date(), sessionId: session.id.uuidString)
  }

  // MARK: - Session helpers

  /// file スコープ時のみ、対象 audioFile に紐づくユーザーメモ本文を読み取る。
  /// メモストアはレジストリ経由で参照するため、将来 MeetingMemo（SwiftData）への
  /// 保存先統一が行われても読み出し先の切り替えだけで追従できる。
  /// メモ本文はユーザーデータのためログへ全文を出さず、プロンプト内でのみ使う。
  /// メモが無い・空の場合は nil を返し、コンテキストへ何も追加しない（従来どおり）。
  private static func currentUserMemoText(scopeType: AskAIScopeType, audioFileID: UUID?) -> String? {
    guard scopeType == .file, let audioFileID else { return nil }
    let text = (try? MemoraNativeMemoRegistry.memoHandler.getMemoDraft(audioFileId: audioFileID.uuidString)) ?? ""
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func fetchSession(id: UUID, in context: ModelContext) -> AskAISession? {
    let descriptor = FetchDescriptor<AskAISession>(
      predicate: #Predicate { $0.id == id }
    )
    return (try? context.fetch(descriptor))?.first
  }

  /// セッションの直近メッセージを新しい順に limit 件取得し、時系列（古い順）で返す。
  private static func fetchRecentMessages(
    sessionID: UUID,
    limit: Int,
    in context: ModelContext
  ) -> [AskAIMessage] {
    var descriptor = FetchDescriptor<AskAIMessage>(
      predicate: #Predicate { $0.sessionID == sessionID },
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    let messages = (try? context.fetch(descriptor)) ?? []
    return messages.reversed()
  }

  /// 永続メッセージをプロンプト内の「これまでの会話」ブロックへ整形する。
  /// 各メッセージの長さを上限で切り詰め、履歴全体のトークン肥大を防ぐ。
  private static func makeHistoryContext(_ messages: [AskAIMessage]) -> String {
    let lines = messages.map { message -> String in
      let speaker: String
      switch message.role {
      case .user: speaker = "ユーザー"
      case .assistant: speaker = "アシスタント"
      case .system: speaker = "システム"
      }
      let content = message.content.count <= HistoryLimit.maxContentLengthPerMessage
        ? message.content
        : String(message.content.prefix(HistoryLimit.maxContentLengthPerMessage)) + "…"
      return "\(speaker): \(content)"
    }
    return "[これまでの会話]\n" + lines.joined(separator: "\n")
  }
}
