import Foundation
import AVFoundation

public struct MemoraPlaybackStatusDTO {
  public let audioFileId: String
  public let isPlaying: Bool
  public let position: Double
  public let duration: Double
  public let rate: Double

  public init(audioFileId: String, isPlaying: Bool, position: Double, duration: Double, rate: Double) {
    self.audioFileId = audioFileId
    self.isPlaying = isPlaying
    self.position = position
    self.duration = duration
    self.rate = rate
  }

  public func asDictionary() -> [String: Any] {
    [
      "audioFileId": audioFileId,
      "isPlaying": isPlaying,
      "position": position,
      "duration": duration,
      "rate": rate
    ]
  }
}

public protocol MemoraPlaybackControlling {
  var sourceDescription: String { get }

  func load(audioFileId: String) throws -> MemoraPlaybackStatusDTO
  func play() throws -> MemoraPlaybackStatusDTO
  func pause() throws -> MemoraPlaybackStatusDTO
  func seek(to position: Double) throws -> MemoraPlaybackStatusDTO
  func setRate(_ rate: Double) throws -> MemoraPlaybackStatusDTO
  func getStatus() throws -> MemoraPlaybackStatusDTO
}

public enum MemoraNativePlaybackRegistry {
  public static var controller: MemoraPlaybackControlling = MemoraAVAudioPlaybackController()
}

enum MemoraPlaybackError: LocalizedError {
  case fileNotFound
  case noFileLoaded

  var errorDescription: String? {
    switch self {
    case .fileNotFound:
      return "この録音には再生可能な音声ファイルがありません。"
    case .noFileLoaded:
      return "先に load を呼び出してください。"
    }
  }
}

public final class MemoraAVAudioPlaybackController: NSObject, MemoraPlaybackControlling {
  public let sourceDescription = "native-file"

  private var player: AVAudioPlayer?
  private var currentAudioFileId: String?

  public override init() {
    super.init()
  }

  public func load(audioFileId: String) throws -> MemoraPlaybackStatusDTO {
    guard let filePath = try MemoraNativeAudioFileMetadataStore.filePath(forId: audioFileId),
          FileManager.default.fileExists(atPath: filePath) else {
      throw MemoraPlaybackError.fileNotFound
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default)
    try session.setActive(true)

    let nextPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath))
    nextPlayer.enableRate = true
    nextPlayer.prepareToPlay()

    player?.stop()
    player = nextPlayer
    currentAudioFileId = audioFileId

    return currentStatus()
  }

  public func play() throws -> MemoraPlaybackStatusDTO {
    guard let player else { throw MemoraPlaybackError.noFileLoaded }
    player.play()
    return currentStatus()
  }

  public func pause() throws -> MemoraPlaybackStatusDTO {
    guard let player else { throw MemoraPlaybackError.noFileLoaded }
    player.pause()
    return currentStatus()
  }

  public func seek(to position: Double) throws -> MemoraPlaybackStatusDTO {
    guard let player else { throw MemoraPlaybackError.noFileLoaded }
    player.currentTime = max(0, min(position, player.duration))
    return currentStatus()
  }

  public func setRate(_ rate: Double) throws -> MemoraPlaybackStatusDTO {
    guard let player else { throw MemoraPlaybackError.noFileLoaded }
    player.rate = Float(rate)
    return currentStatus()
  }

  public func getStatus() throws -> MemoraPlaybackStatusDTO {
    guard player != nil else { throw MemoraPlaybackError.noFileLoaded }
    return currentStatus()
  }

  private func currentStatus() -> MemoraPlaybackStatusDTO {
    guard let player else {
      return MemoraPlaybackStatusDTO(audioFileId: currentAudioFileId ?? "", isPlaying: false, position: 0, duration: 0, rate: 1)
    }

    return MemoraPlaybackStatusDTO(
      audioFileId: currentAudioFileId ?? "",
      isPlaying: player.isPlaying,
      position: player.currentTime,
      duration: player.duration,
      rate: Double(player.rate == 0 ? 1 : player.rate)
    )
  }
}
