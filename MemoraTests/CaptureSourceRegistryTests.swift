import Foundation
import Testing
@testable import Memora

@MainActor
struct CaptureSourceRegistryTests {
    @Test("Registry は unavailable source を除外して検索できる")
    func registryFiltersUnavailableSources() {
        let omi = FakeCaptureSource(sourceType: .omi, tier: .bleDirect, state: .idle)
        let generic = FakeCaptureSource(sourceType: .genericDevice, tier: .fileImport, state: .idle)
        let unavailable = FakeCaptureSource(sourceType: .plaudCloud, tier: .cloudSync, state: .unavailable)

        let registry = CaptureSourceRegistry(
            sources: [omi, generic, unavailable],
            sink: { url, title in AudioFile(title: title ?? "Imported", audioURL: url.path) }
        )

        #expect(registry.sources.count == 2)
        #expect(registry.source(for: .omi) != nil)
        #expect(registry.source(for: .genericDevice) != nil)
        #expect(registry.source(for: .plaudCloud) == nil)
        #expect(omi.configureCount == 1)
        #expect(generic.configureCount == 1)
        #expect(unavailable.configureCount == 1)
    }

    @Test("Registry は devices を tier 順に集約する")
    func registrySortsDevicesByTier() {
        let fileDevice = CaptureDevice(
            id: "file",
            displayName: "Generic File",
            sourceType: .genericDevice,
            tier: .fileImport
        )
        let bleDevice = CaptureDevice(
            id: "omi",
            displayName: "Omi Device",
            sourceType: .omi,
            tier: .bleDirect
        )
        let generic = FakeCaptureSource(
            sourceType: .genericDevice,
            tier: .fileImport,
            devices: [fileDevice],
            state: .idle
        )
        let omi = FakeCaptureSource(
            sourceType: .omi,
            tier: .bleDirect,
            devices: [bleDevice],
            state: .idle
        )

        let registry = CaptureSourceRegistry(
            sources: [generic, omi],
            sink: { url, title in AudioFile(title: title ?? "Imported", audioURL: url.path) }
        )

        #expect(registry.allDevices.map(\.id) == ["omi", "file"])
    }

    @Test("startAllDiscovery は fileImport tier をスキップする")
    func startAllDiscoverySkipsFileImportSources() async {
        let omi = FakeCaptureSource(sourceType: .omi, tier: .bleDirect, state: .idle)
        let generic = FakeCaptureSource(sourceType: .genericDevice, tier: .fileImport, state: .idle)
        let registry = CaptureSourceRegistry(
            sources: [omi, generic],
            sink: { url, title in AudioFile(title: title ?? "Imported", audioURL: url.path) }
        )

        await registry.startAllDiscovery()

        #expect(omi.startDiscoveryCount == 1)
        #expect(generic.startDiscoveryCount == 0)
    }
}

@MainActor
private final class FakeCaptureSource: CaptureSource {
    let sourceType: SourceType
    let tier: ConnectionTier
    var captureDevices: [CaptureDevice]
    var captureConnectionState: CaptureConnectionState
    var configureCount = 0
    var startDiscoveryCount = 0

    init(
        sourceType: SourceType,
        tier: ConnectionTier,
        devices: [CaptureDevice] = [],
        state: CaptureConnectionState
    ) {
        self.sourceType = sourceType
        self.tier = tier
        self.captureDevices = devices
        self.captureConnectionState = state
    }

    func configure(sink: @escaping ImportSink) {
        configureCount += 1
    }

    func startDiscovery() async {
        startDiscoveryCount += 1
    }

    func stopDiscovery() {
    }

    func connect(to device: CaptureDevice) async throws {
    }

    func disconnect() {
    }
}
