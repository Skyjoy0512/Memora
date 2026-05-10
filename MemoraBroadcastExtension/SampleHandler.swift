import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var outputURL: URL?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.memora.broadcast"
        ) else {
            finishBroadcastWithError(NSError(
                domain: "MemoraBroadcast",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "App Group container not available"]
            ))
            return
        }

        let captureDir = containerURL.appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)

        let fileName = "meeting_capture_\(UUID().uuidString.prefix(8)).m4a"
        let fileURL = captureDir.appendingPathComponent(fileName)
        outputURL = fileURL

        try? FileManager.default.removeItem(at: fileURL)

        do {
            assetWriter = try AVAssetWriter(url: fileURL, fileType: .m4a)

            var channelLayout = AudioChannelLayout()
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono

            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000,
                AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout<AudioChannelLayout>.size)
            ]

            assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true

            if let input = assetWriterInput, assetWriter?.canAdd(input) == true {
                assetWriter?.add(input)
            }
        } catch {
            finishBroadcastWithError(error)
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .audioApp || type == .audioMic else { return }

        guard let writer = assetWriter, let input = assetWriterInput else { return }

        if !sessionStarted {
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            sessionStarted = true
        }

        guard writer.status == .writing else { return }

        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    override func broadcastFinished() {
        sessionStarted = false

        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            self?.assetWriter = nil
            self?.assetWriterInput = nil
        }
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}
}
