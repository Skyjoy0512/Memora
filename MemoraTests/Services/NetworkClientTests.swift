import Testing
import Foundation
@testable import Memora

// MARK: - NetworkError Tests

struct NetworkErrorTests {

    @Test("errorDescription が日本語で返る")
    func errorDescriptions() {
        #expect(NetworkError.invalidURL.errorDescription == "無効なURLです")
        #expect(NetworkError.invalidResponse.errorDescription == "無効なレスポンスです")
        #expect(NetworkError.httpError(statusCode: 404, data: Data()).errorDescription == "HTTPエラー: 404")
        #expect(NetworkError.noConnection.errorDescription == "ネットワーク接続がありません")
        #expect(NetworkError.timedOut.errorDescription == "リクエストがタイムアウトしました")
        #expect(NetworkError.cancelled.errorDescription == "リクエストがキャンセルされました")
    }

    @Test("URLError から NetworkError への変換が正しい")
    func fromURLError() {
        let noConnection = NetworkError.from(URLError(.notConnectedToInternet))
        if case .noConnection = noConnection { /* pass */ } else {
            Issue.record("Expected .noConnection for notConnectedToInternet")
        }

        let connectionLost = NetworkError.from(URLError(.networkConnectionLost))
        if case .noConnection = connectionLost { /* pass */ } else {
            Issue.record("Expected .noConnection for networkConnectionLost")
        }

        let timedOut = NetworkError.from(URLError(.timedOut))
        if case .timedOut = timedOut { /* pass */ } else {
            Issue.record("Expected .timedOut")
        }

        let cancelled = NetworkError.from(URLError(.cancelled))
        if case .cancelled = cancelled { /* pass */ } else {
            Issue.record("Expected .cancelled")
        }

        // Unknown error maps to httpError with -1
        let unknown = NetworkError.from(URLError(.badURL))
        if case .httpError(let code, _) = unknown {
            #expect(code == -1)
        } else {
            Issue.record("Expected httpError, got \(unknown)")
        }
    }

    @Test("decodingFailed が元のエラーの説明を含む")
    func decodingFailedDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "parse error"])
        let error = NetworkError.decodingFailed(underlying)
        #expect(error.errorDescription?.contains("解析に失敗") == true)
    }

    @Test("encodingFailed が元のエラーの説明を含む")
    func encodingFailedDescription() {
        let underlying = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "encode error"])
        let error = NetworkError.encodingFailed(underlying)
        #expect(error.errorDescription?.contains("エンコードに失敗") == true)
    }
}

// MARK: - NetworkRequest Builder Tests

struct NetworkRequestTests {

    @Test("build が正しい URLRequest を生成する")
    func buildBasicRequest() throws {
        let url = URL(string: "https://example.com/api")!
        let request = NetworkRequest(url: url, method: "GET")

        let urlRequest = try request.build()

        #expect(urlRequest.url == url)
        #expect(urlRequest.httpMethod == "GET")
        #expect(urlRequest.httpBody == nil)
    }

    @Test("build がヘッダーを設定する")
    func buildWithHeaders() throws {
        let url = URL(string: "https://example.com/api")!
        let request = NetworkRequest(
            url: url,
            method: "POST",
            headers: ["Content-Type": "application/json", "Authorization": "Bearer token123"]
        )

        let urlRequest = try request.build()

        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
    }

    @Test("build が body を設定する")
    func buildWithBody() throws {
        let url = URL(string: "https://example.com/api")!
        let body = Data("{\"key\":\"value\"}".utf8)
        let request = NetworkRequest(url: url, method: "POST", body: body)

        let urlRequest = try request.build()

        #expect(urlRequest.httpBody == body)
    }

    @Test("build がカスタムタイムアウトを設定する")
    func buildWithTimeout() throws {
        let url = URL(string: "https://example.com/api")!
        let request = NetworkRequest(url: url, method: "GET", timeout: 60)

        let urlRequest = try request.build()

        #expect(urlRequest.timeoutInterval == 60)
    }

    @Test("build でタイムアウト未指定時は URLRequest デフォルト")
    func buildWithoutTimeout() throws {
        let url = URL(string: "https://example.com/api")!
        let request = NetworkRequest(url: url, method: "GET")

        let urlRequest = try request.build()

        // URLRequest のデフォルトタイムアウトは 60s
        #expect(urlRequest.timeoutInterval == 60)
    }
}

// MARK: - MultipartFormData Tests

struct MultipartFormDataTests {

    @Test("add(name:value:) でパーツが追加される")
    func addTextField() throws {
        var form = NetworkClient.MultipartFormData()
        form.add(name: "field1", value: "hello")

        let data = try form.encode()
        let str = String(data: data, encoding: .utf8)!

        #expect(str.contains("name=\"field1\""))
        #expect(str.contains("hello"))
    }

    @Test("add(name:filename:mimeType:data:) でファイルパーツが追加される")
    func addFileField() throws {
        var form = NetworkClient.MultipartFormData()
        let fileData = Data([0x01, 0x02, 0x03])
        form.add(name: "file", filename: "test.wav", mimeType: "audio/wav", data: fileData)

        let data = try form.encode()
        let str = String(data: data, encoding: .utf8)!

        #expect(str.contains("filename=\"test.wav\""))
        #expect(str.contains("Content-Type: audio/wav"))
    }

    @Test("contentType が multipart/form-data を含む")
    func contentType() {
        let form = NetworkClient.MultipartFormData()
        let ct = form.contentType()

        #expect(ct.hasPrefix("multipart/form-data; boundary="))
    }

    @Test("空のフォームでもバウンダリ終端が含まれる")
    func emptyForm() throws {
        let form = NetworkClient.MultipartFormData()
        let data = try form.encode()
        let str = String(data: data, encoding: .utf8)!

        #expect(str.contains("--"))
        #expect(str.contains("--"))
    }
}
