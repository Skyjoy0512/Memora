import Foundation

actor PlaudMCPClient {
    static let endpoint = URL(string: "https://mcp.plaud.ai/mcp")!
    private let session: URLSession
    private let accessToken: String
    private var sessionID: String?
    private var requestID = 0

    init(accessToken: String, session: URLSession = .plaudMCP) {
        self.accessToken = accessToken
        self.session = session
    }

    func listFiles(since: Date?) async throws -> [PlaudMCPFile] {
        var arguments: [String: JSONValue] = ["page_size": .number(100)]
        if let since {
            let formatter = ISO8601DateFormatter()
            arguments["date_from"] = .string(formatter.string(from: since).prefix(10).description)
        }
        let data = try await callTool(name: "list_files", arguments: arguments)
        return try PlaudMCPResponseDecoder.decodeFiles(from: data)
    }

    func getFile(id: String) async throws -> PlaudMCPFile {
        let data = try await callTool(name: "get_file", arguments: ["id": .string(id)])
        return try PlaudMCPResponseDecoder.decodeFile(from: data)
    }

    private func callTool(name: String, arguments: [String: JSONValue]) async throws -> Data {
        try await initializeIfNeeded()
        let response = try await send(method: "tools/call", params: ToolCallParameters(name: name, arguments: arguments))
        return try PlaudMCPResponseDecoder.extractTextPayload(from: response)
    }

    private func initializeIfNeeded() async throws {
        guard sessionID == nil else { return }
        _ = try await send(
            method: "initialize",
            params: InitializeParameters(
                protocolVersion: "2025-03-26",
                capabilities: EmptyParameters(),
                clientInfo: ClientInfo(name: "Memora", version: "1.0")
            )
        )
    }

    private func send<Parameters: Encodable & Sendable>(method: String, params: Parameters) async throws -> Data {
        requestID += 1
        let payload = JSONRPCRequest(id: requestID, method: method, params: params)
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw PlaudMCPToolError(message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw PlaudMCPToolError(message: "PLAUD MCPから無効な応答を受け取りました")
        }
        if let returnedSessionID = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
            sessionID = returnedSessionID
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw PlaudMCPToolError(message: "PLAUDへの再接続が必要です")
            }
            throw PlaudMCPToolError(message: "PLAUD MCPエラー (\(http.statusCode))")
        }
        return data
    }
}

private extension URLSession {
    static let plaudMCP: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
}

private struct JSONRPCRequest<Parameters: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: Parameters
}

private struct InitializeParameters: Encodable, Sendable {
    let protocolVersion: String
    let capabilities: EmptyParameters
    let clientInfo: ClientInfo
}

private struct EmptyParameters: Encodable, Sendable {}
private struct ClientInfo: Encodable, Sendable { let name: String; let version: String }
private struct ToolCallParameters: Encodable, Sendable { let name: String; let arguments: [String: JSONValue] }

enum JSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

private enum PlaudMCPResponseDecoder {
    private struct Envelope: Decodable {
        struct Result: Decodable { let content: [Content]? }
        struct Content: Decodable { let type: String; let text: String? }
        struct Error: Decodable { let message: String }
        let result: Result?
        let error: Error?
    }

    static func extractTextPayload(from data: Data) throws -> Data {
        let envelope = try JSONDecoder().decode(Envelope.self, from: normalizedJSONRPCPayload(from: data))
        if let error = envelope.error { throw PlaudMCPToolError(message: error.message) }
        let text = envelope.result?.content?
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n") ?? ""
        guard !text.isEmpty else { throw PlaudMCPToolError(message: "PLAUD MCPの応答にデータがありません") }
        let trimmed = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let payload = trimmed.data(using: .utf8) else {
            throw PlaudMCPToolError(message: "PLAUD MCPの応答を読み取れません")
        }
        return payload
    }

    private static func normalizedJSONRPCPayload(from data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8), text.hasPrefix("data:") else { return data }
        let payload = text
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let prefix = "data:"
                guard line.hasPrefix(prefix) else { return nil }
                return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
        return payload.data(using: .utf8) ?? data
    }

    static func decodeFiles(from data: Data) throws -> [PlaudMCPFile] {
        let decoder = JSONDecoder()
        if let files = try? decoder.decode([PlaudMCPFile].self, from: data) { return files }
        let container = try decoder.decode(FileListContainer.self, from: data)
        return container.files ?? container.data ?? container.items ?? []
    }

    static func decodeFile(from data: Data) throws -> PlaudMCPFile {
        let decoder = JSONDecoder()
        if let file = try? decoder.decode(PlaudMCPFile.self, from: data) { return file }
        let container = try decoder.decode(FileContainer.self, from: data)
        guard let file = container.file ?? container.data else {
            throw PlaudMCPToolError(message: "PLAUD録音の詳細を読み取れません")
        }
        return file
    }

    private struct FileListContainer: Decodable {
        let files: [PlaudMCPFile]?
        let data: [PlaudMCPFile]?
        let items: [PlaudMCPFile]?
    }
    private struct FileContainer: Decodable { let file: PlaudMCPFile?; let data: PlaudMCPFile? }
}
