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

public final class MemoraAVAudioPlaybackController: NSObject, MemoraPlaybackControlling, AVAudioPlayerDelegate {
  public let sourceDescription = "native-file"

  private var player: AVAudioPlayer?
  private var segmentPlayers: [AVAudioPlayer] = []
  private var segmentStartOffsets: [TimeInterval] = []
  private var currentSegmentIndex = 0
  private var currentAudioFileId: String?
  private var playbackRate: Float = 1

  public override init() {
    super.init()
  }

  public func load(audioFileId: String) throws -> MemoraPlaybackStatusDTO {
    let filePaths = try MemoraNativeAudioFileReaderRegistry.audioFileReader.playbackFilePaths(forId: audioFileId)
    guard !filePaths.isEmpty,
          filePaths.allSatisfy({ FileManager.default.fileExists(atPath: $0) }) else {
      throw MemoraPlaybackError.fileNotFound
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default)
    try session.setActive(true)

    let nextPlayers = try filePaths.map { filePath in
      let nextPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath))
      nextPlayer.enableRate = true
      nextPlayer.delegate = self
      nextPlayer.prepareToPlay()
      return nextPlayer
    }

    player?.stop()
    segmentPlayers = nextPlayers
    var offset: TimeInterval = 0
    segmentStartOffsets = nextPlayers.map { segmentPlayer in
      defer { offset += segmentPlayer.duration }
      return offset
    }
    currentSegmentIndex = 0
    playbackRate = 1
    player = nextPlayers[0]
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
    let totalDuration = segmentPlayers.reduce(0) { $0 + $1.duration }
    let clampedPosition = max(0, min(position, totalDuration))
    let targetIndex = segmentStartOffsets.lastIndex(where: { $0 <= clampedPosition }) ?? 0
    let targetPlayer = segmentPlayers[targetIndex]
    let wasPlaying = player.isPlaying

    if targetPlayer !== player {
      player.stop()
      self.player = targetPlayer
      currentSegmentIndex = targetIndex
    }

    targetPlayer.currentTime = min(
      max(0, clampedPosition - segmentStartOffsets[targetIndex]),
      targetPlayer.duration
    )
    targetPlayer.rate = playbackRate
    if wasPlaying {
      targetPlayer.play()
    }
    return currentStatus()
  }

  public func setRate(_ rate: Double) throws -> MemoraPlaybackStatusDTO {
    guard let player else { throw MemoraPlaybackError.noFileLoaded }
    playbackRate = Float(rate)
    player.rate = playbackRate
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
      position: segmentStartOffsets[currentSegmentIndex] + player.currentTime,
      duration: segmentPlayers.reduce(0) { $0 + $1.duration },
      rate: Double(player.rate == 0 ? 1 : player.rate)
    )
  }

  public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard flag,
          currentSegmentIndex + 1 < segmentPlayers.count,
          player === self.player else {
      return
    }

    currentSegmentIndex += 1
    let nextPlayer = segmentPlayers[currentSegmentIndex]
    nextPlayer.rate = playbackRate
    self.player = nextPlayer
    nextPlayer.play()
  }
}
