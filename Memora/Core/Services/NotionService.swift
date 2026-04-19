import Foundation
import SwiftData

/// Notion REST API クライアント。
/// Internal Integration Token を使用してページ作成・ブロック追加を行う。
final class NotionService {

    private static let notionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()

    // MARK: - Error

    enum NotionError: LocalizedError {
        case notConfigured
        case invalidToken
        case pageNotFound
        case networkError(Error)
        case serverError(Int, String?)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Notion 連携が設定されていません。"
            case .invalidToken:
                return "Notion トークンが無効です。設定を確認してください。"
            case .pageNotFound:
                return "指定されたページが見つかりません。"
            case .networkError(let error):
                return "通信エラー: \(error.localizedDescription)"
            case .serverError(let code, let message):
                return "Notion エラー (\(code)): \(message ?? "不明なエラー")"
            case .decodingError(let error):
                return "データの解析に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - DTOs

    struct NotionUser: Codable {
        let id: String
        let name: String?
        let type: String?
    }

    struct NotionPage: Codable {
        let id: String
        let url: String?
        let createdTime: String?

        enum CodingKeys: String, CodingKey {
            case id, url
            case createdTime = "created_time"
        }
    }

    struct NotionSearchResult: Codable {
        let id: String
        let type: String?
        let title: String?

        enum CodingKeys: String, CodingKey {
            case id, type, title
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            type = try container.decodeIfPresent(String.self, forKey: .type)

            // title は object 型の配列からテキストを抽出
            if let titleContainer = try? container.decodeIfPresent([TitleItem].self, forKey: .title) {
                title = titleContainer.compactMap { $0.plainText }.joined()
            } else if let titleStr = try? container.decodeIfPresent(String.self, forKey: .title) {
                title = titleStr
            } else {
                title = nil
            }
        }

        struct TitleItem: Codable {
            let plainText: String?
            enum CodingKeys: String, CodingKey {
                case plainText = "plain_text"
            }
        }
    }

    struct NotionSearchResponse: Codable {
        let results: [NotionSearchResult]?
        let hasMore: Bool?

        enum CodingKeys: String, CodingKey {
            case results
            case hasMore = "has_more"
        }
    }

    // MARK: - Properties

    private let networkClient: NetworkClient
    private let apiVersion = "2022-06-28"
    private let baseURL = "https://api.notion.com/v1"

    init(networkClient: NetworkClient = .init()) {
        self.networkClient = networkClient
    }

    // MARK: - Connection Test

    /// トークンの有効性を確認する。
    func testConnection(token: String) async throws -> NotionUser {
        let url = URL(string: "\(baseURL)/users/me")!

        do {
            return try await networkClient.get(
                url: url,
                headers: [
                    "Authorization": "Bearer \(token)",
                    "Notion-Version": apiVersion,
                    "Content-Type": "application/json"
                ],
                responseType: NotionUser.self
            )
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        } catch {
            throw NotionError.decodingError(error)
        }
    }

    // MARK: - Search

    /// ページ / データベースを検索する（親ページ選択用）。
    func searchPages(token: String, query: String = "") async throws -> [NotionSearchResult] {
        let url = URL(string: "\(baseURL)/search")!

        struct SearchRequest: Codable {
            let query: String?
            let pageSize: Int

            enum CodingKeys: String, CodingKey {
                case query
                case pageSize = "page_size"
            }
        }

        let searchRequest = SearchRequest(
            query: query.isEmpty ? nil : query,
            pageSize: 20
        )

        do {
            let response: NotionSearchResponse = try await networkClient.postJSON(
                url: url,
                headers: [
                    "Authorization": "Bearer \(token)",
                    "Notion-Version": apiVersion
                ],
                body: searchRequest,
                responseType: NotionSearchResponse.self
            )
            return response.results ?? []
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        } catch {
            throw NotionError.decodingError(error)
        }
    }

    // MARK: - Create Page (Full Export)

    /// AudioFile から Notion ページを作成（要約 + 文字起こし全文 + タスク）。
    func createPageFromAudioFile(
        audioFile: AudioFile,
        transcriptText: String?,
        todoItems: [TodoItem] = [],
        modelContext: ModelContext,
        token: String,
        parentPageID: String
    ) async throws -> NotionPage {
        let dateString = Self.notionDateFormatter.string(from: audioFile.createdAt)

        let title = "\(audioFile.title) — \(dateString)"

        var blocks: [[String: Any]] = []

        // Summary
        if let summary = audioFile.summary, !summary.isEmpty {
            blocks.append(headingBlock(text: "Summary", level: 2))
            blocks.append(paragraphBlock(text: summary))
            blocks.append(dividerBlock())
        }

        // Key Points
        if let keyPoints = audioFile.keyPoints, !keyPoints.isEmpty {
            blocks.append(headingBlock(text: "Key Points", level: 2))
            for point in keyPoints.split(separator: "\n", omittingEmptySubsequences: true) {
                blocks.append(bulletedListItem(text: String(point)))
            }
            blocks.append(dividerBlock())
        }

        // Action Items
        if let actionItems = audioFile.actionItems, !actionItems.isEmpty {
            blocks.append(headingBlock(text: "Action Items", level: 2))
            for item in actionItems.split(separator: "\n", omittingEmptySubsequences: true) {
                blocks.append(toDoBlock(text: String(item), checked: false))
            }
            blocks.append(dividerBlock())
        }

        // Tasks (from TodoItem)
        if !todoItems.isEmpty {
            blocks.append(headingBlock(text: "Tasks", level: 2))
            for todo in todoItems {
                blocks.append(toDoBlock(text: todo.title, checked: todo.isCompleted))
            }
            blocks.append(dividerBlock())
        }

        // Memo
        let memoText = fetchMemoText(audioFileID: audioFile.id, modelContext: modelContext)
        if let memoText, !memoText.isEmpty {
            blocks.append(headingBlock(text: "Memo", level: 2))
            blocks.append(paragraphBlock(text: memoText))
            blocks.append(dividerBlock())
        }

        // Transcript (toggle block)
        if let transcriptText, !transcriptText.isEmpty {
            blocks.append(headingBlock(text: "Transcript", level: 2))
            blocks.append(toggleBlock(
                title: "文字起こし全文を表示",
                children: splitTranscriptBlocks(transcriptText)
            ))
        }

        return try await createPage(
            title: title,
            parentPageID: parentPageID,
            blocks: blocks,
            token: token
        )
    }

    // MARK: - Export Summary Only

    /// 要約のみを Notion ページとしてエクスポート。
    func exportSummary(
        audioFile: AudioFile,
        token: String,
        parentPageID: String
    ) async throws -> NotionPage {
        let title = "\(audioFile.title) (Summary) — \(Self.notionDateFormatter.string(from: audioFile.createdAt))"

        var blocks: [[String: Any]] = []

        if let summary = audioFile.summary, !summary.isEmpty {
            blocks.append(paragraphBlock(text: summary))
            blocks.append(dividerBlock())
        }

        if let keyPoints = audioFile.keyPoints, !keyPoints.isEmpty {
            blocks.append(headingBlock(text: "Key Points", level: 3))
            for point in keyPoints.split(separator: "\n", omittingEmptySubsequences: true) {
                blocks.append(bulletedListItem(text: String(point)))
            }
        }

        if let actionItems = audioFile.actionItems, !actionItems.isEmpty {
            blocks.append(headingBlock(text: "Action Items", level: 3))
            for item in actionItems.split(separator: "\n", omittingEmptySubsequences: true) {
                blocks.append(toDoBlock(text: String(item), checked: false))
            }
        }

        return try await createPage(
            title: title,
            parentPageID: parentPageID,
            blocks: blocks,
            token: token
        )
    }

    // MARK: - Export Transcript Only

    /// 文字起こしのみを Notion ページとしてエクスポート（toggle ブロック内）。
    func exportTranscript(
        transcriptText: String,
        audioFile: AudioFile,
        token: String,
        parentPageID: String
    ) async throws -> NotionPage {
        let title = "\(audioFile.title) (Transcript) — \(Self.notionDateFormatter.string(from: audioFile.createdAt))"

        let blocks: [[String: Any]] = [
            toggleBlock(
                title: "文字起こし全文を表示",
                children: splitTranscriptBlocks(transcriptText)
            )
        ]

        return try await createPage(
            title: title,
            parentPageID: parentPageID,
            blocks: blocks,
            token: token
        )
    }

    // MARK: - Private: Page Creation

    private func createPage(
        title: String,
        parentPageID: String,
        blocks: [[String: Any]],
        token: String
    ) async throws -> NotionPage {
        let url = URL(string: "\(baseURL)/pages")!

        struct PageRequest: Encodable {
            let parent: [String: String]
            let properties: [String: [[String: String]]]
            let children: [[String: Any]]

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(parent, forKey: .parent)
                try container.encode(properties, forKey: .properties)

                // children は Any 型を含むため、手動エンコード
                let childrenData = try JSONSerialization.data(withJSONObject: children)
                let childrenString = String(data: childrenData, encoding: .utf8) ?? "[]"
                try container.encode(childrenString, forKey: .children)
            }

            enum CodingKeys: String, CodingKey {
                case parent, properties, children
            }
        }

        let pageRequest: [String: Any] = [
            "parent": ["page_id": parentPageID],
            "properties": [
                "title": [
                    "title": [["text": ["content": title]]]
                ]
            ],
            "children": blocks
        ]

        do {
            let requestData = try JSONSerialization.data(withJSONObject: pageRequest)
            return try await networkClient.post(
                url: url,
                headers: [
                    "Authorization": "Bearer \(token)",
                    "Notion-Version": apiVersion,
                    "Content-Type": "application/json"
                ],
                body: requestData,
                responseType: NotionPage.self
            )
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        } catch {
            throw NotionError.decodingError(error)
        }
    }

    // MARK: - Private: Block Builders

    private func headingBlock(text: String, level: Int) -> [String: Any] {
        let type = "heading_\(level)"
        return [
            "object": "block",
            "type": type,
            type: [
                "rich_text": [["text": ["content": text]]]
            ]
        ]
    }

    private func paragraphBlock(text: String) -> [String: Any] {
        // Notion API の rich_text ブロックは 2000 文字制限
        return [
            "object": "block",
            "type": "paragraph",
            "paragraph": [
                "rich_text": [["text": ["content": String(text.prefix(2000))]]]
            ]
        ]
    }

    private func toggleBlock(title: String, children: [[String: Any]]) -> [String: Any] {
        return [
            "object": "block",
            "type": "toggle",
            "toggle": [
                "rich_text": [["text": ["content": title]]],
                "children": children
            ]
        ]
    }

    private func toDoBlock(text: String, checked: Bool) -> [String: Any] {
        return [
            "object": "block",
            "type": "to_do",
            "to_do": [
                "rich_text": [["text": ["content": String(text.prefix(2000))]]],
                "checked": checked
            ]
        ]
    }

    private func bulletedListItem(text: String) -> [String: Any] {
        return [
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": [
                "rich_text": [["text": ["content": String(text.prefix(2000))]]]
            ]
        ]
    }

    private func dividerBlock() -> [String: Any] {
        return [
            "object": "block",
            "type": "divider",
            "divider": [:]
        ]
    }

    // MARK: - Private: Helpers

    /// 長い文字起こしテキストを 2000 文字単位の paragraph ブロックに分割する。
    private func splitTranscriptBlocks(_ text: String) -> [[String: Any]] {
        let chunkSize = 2000
        var blocks: [[String: Any]] = []
        var startIndex = text.startIndex

        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[startIndex..<endIndex])
            blocks.append(paragraphBlock(text: chunk))
            startIndex = endIndex
        }

        return blocks
    }

    /// AudioFile に紐付いた MeetingMemo の markdown を取得する。
    private func fetchMemoText(audioFileID: UUID, modelContext: ModelContext) -> String? {
        let targetID = audioFileID
        var descriptor = FetchDescriptor<MeetingMemo>(
            predicate: #Predicate { $0.audioFileID == targetID }
        )
        descriptor.fetchLimit = 1
        let memo = try? modelContext.fetch(descriptor).first
        return memo?.markdown
    }

    // MARK: - Private: Helpers

    private func mapNetworkError(_ error: NetworkError) -> NotionError {
        switch error {
        case .httpError(let code, _):
            switch code {
            case 401:
                return .invalidToken
            case 404:
                return .pageNotFound
            default:
                return .serverError(code, nil)
            }
        case .noConnection, .timedOut:
            return .networkError(error)
        default:
            return .networkError(error)
        }
    }
}
