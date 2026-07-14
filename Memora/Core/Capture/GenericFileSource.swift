import Foundation
import Observation

@MainActor
@Observable
final class GenericFileSource: CaptureSource {
    private let supportedExtensions: Set<String> = ["m4a", "wav", "mp3", "caf", "aac"]
    private var sink: ImportSink?

    var sourceType: SourceType { .genericDevice }
    var tier: ConnectionTier { .fileImport }
    var captureDevices: [CaptureDevice] { [] }
    var captureConnectionState: CaptureConnectionState { .idle }

    func configure(sink: @escaping ImportSink) {
        self.sink = sink
    }

    func startDiscovery() async {
    }

    func stopDiscovery() {
    }

    func connect(to device: CaptureDevice) async throws {
    }

    func disconnect() {
    }

    func importFile(at url: URL) async throws -> AudioFile {
        let fileExtension = url.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw CaptureError.unsupportedFormat(url.pathExtension)
        }

        guard let sink else {
            throw CaptureError.importSinkNotConfigured
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let title = url.deletingPathExtension().lastPathComponent
        let audioFile = try await sink(url, title)
        audioFile.sourceTypeRaw = SourceType.genericDevice.rawValue
        return audioFile
    }
}
