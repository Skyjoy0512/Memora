import Foundation
import Observation

@MainActor
@Observable
final class CaptureSourceRegistry {
    private(set) var sources: [any CaptureSource]

    convenience init(sink: @escaping ImportSink) {
        self.init(
            sources: [OmiAdapter(), GenericFileSource()],
            sink: sink
        )
    }

    init(sources: [any CaptureSource], sink: @escaping ImportSink) {
        sources.forEach { $0.configure(sink: sink) }
        self.sources = sources.filter { $0.captureConnectionState != .unavailable }
    }

    var allDevices: [CaptureDevice] {
        sources
            .flatMap(\.captureDevices)
            .sorted { lhs, rhs in
                if lhs.tier.rawValue != rhs.tier.rawValue {
                    return lhs.tier.rawValue < rhs.tier.rawValue
                }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    var omiAdapter: OmiAdapter? {
        source(for: .omi) as? OmiAdapter
    }

    var genericFileSource: GenericFileSource? {
        source(for: .genericDevice) as? GenericFileSource
    }

    func configure(sink: @escaping ImportSink) {
        sources.forEach { $0.configure(sink: sink) }
    }

    func startAllDiscovery() async {
        for source in sources where source.tier != .fileImport {
            await source.startDiscovery()
        }
    }

    func source(for type: SourceType) -> (any CaptureSource)? {
        sources.first { $0.sourceType == type }
    }
}

extension CaptureSourceRegistry {
    static var preview: CaptureSourceRegistry {
        CaptureSourceRegistry { audioURL, title in
            AudioFile(
                title: title ?? audioURL.deletingPathExtension().lastPathComponent,
                audioURL: audioURL.path
            )
        }
    }
}
