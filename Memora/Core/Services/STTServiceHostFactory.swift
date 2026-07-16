import Foundation

/// App-host composition root for the STT core. Keep `.live` implementations
/// out of STTService so the service can move to MemoraSharedCore unchanged.
enum STTServiceHostFactory {
    static func makeLive() -> STTService {
        let dependencies = STTReadOnlyHostDependencies.live
        return STTService(
            readiness: STTReadiness(),
            chunkerFactory: { AudioChunker() },
            dependencies: dependencies,
            capabilities: .live,
            executionDependencies: .live(dependencies: dependencies)
        )
    }
}
