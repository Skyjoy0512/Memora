import Testing
import Foundation
@testable import Memora

struct OpenAIExportServiceTests {

    // MARK: - DTO Tests

    @Test("OpenAIExportFormat rawValue が正しい")
    func exportFormatRawValues() {
        #expect(OpenAIExportFormat.json.rawValue == "json")
        #expect(OpenAIExportFormat.markdown.rawValue == "markdown")
        #expect(OpenAIExportFormat.allCases.count == 2)
    }

    @Test("OpenAIFilePurpose rawValue が正しい")
    func filePurposeRawValues() {
        #expect(OpenAIFilePurpose.assistants.rawValue == "assistants")
        #expect(OpenAIFilePurpose.userData.rawValue == "user_data")
    }

    @Test("OpenAIFileUploadResult の Equatable が正しく動作する")
    func uploadResultEquality() {
        let date = Date()
        let result1 = OpenAIFileUploadResult(
            fileId: "file-abc123",
            filename: "test.json",
            bytes: 1024,
            purpose: "user_data",
            createdAt: date
        )
        let result2 = OpenAIFileUploadResult(
            fileId: "file-abc123",
            filename: "test.json",
            bytes: 1024,
            purpose: "user_data",
            createdAt: date
        )
        let result3 = OpenAIFileUploadResult(
            fileId: "file-xyz",
            filename: "test.json",
            bytes: 1024,
            purpose: "user_data",
            createdAt: date
        )

        #expect(result1 == result2)
        #expect(result1 != result3)
    }

    // MARK: - Error Description Tests

    @Test("OpenAIExportError の全ケースの errorDescription が非空")
    func errorDescriptionsAreNonEmpty() {
        let errors: [OpenAIExportError] = [
            .apiKeyMissing,
            .noDataToExport,
            .fileTooLarge(maxBytes: 512 * 1024 * 1024),
            .networkError("timeout"),
            .apiError(statusCode: 401, message: "unauthorized"),
            .invalidResponse,
            .encodingFailed,
            .rateLimitExceeded
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("OpenAIExportError の Equatable が正しく動作する")
    func errorEquality() {
        #expect(OpenAIExportError.apiKeyMissing == OpenAIExportError.apiKeyMissing)
        #expect(OpenAIExportError.apiKeyMissing != OpenAIExportError.noDataToExport)
        #expect(
            OpenAIExportError.apiError(statusCode: 401, message: "unauthorized")
            == OpenAIExportError.apiError(statusCode: 401, message: "unauthorized")
        )
        #expect(
            OpenAIExportError.apiError(statusCode: 401, message: "a")
            != OpenAIExportError.apiError(statusCode: 401, message: "b")
        )
    }

    @Test("fileTooLarge のエラーメッセージに MB 単位が含まれる")
    func fileTooLargeMessage() {
        let error = OpenAIExportError.fileTooLarge(maxBytes: 512 * 1024 * 1024)
        #expect(error.errorDescription?.contains("536") == true)
    }
}
