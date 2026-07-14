import Foundation

@MainActor
protocol CaptureSource: AnyObject {
    var sourceType: SourceType { get }
    var tier: ConnectionTier { get }
    var captureDevices: [CaptureDevice] { get }
    var captureConnectionState: CaptureConnectionState { get }

    func configure(sink: @escaping ImportSink)
    func startDiscovery() async
    func stopDiscovery()
    func connect(to device: CaptureDevice) async throws
    func disconnect()
}
