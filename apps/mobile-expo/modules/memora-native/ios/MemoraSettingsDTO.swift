import Foundation

public struct MemoraSettingsDTO {
  public let transcriptionMode: String
  public let summaryProvider: String
  public let speechAnalyzerEnabled: Bool

  public init(
    transcriptionMode: String,
    summaryProvider: String,
    speechAnalyzerEnabled: Bool
  ) {
    self.transcriptionMode = transcriptionMode
    self.summaryProvider = summaryProvider
    self.speechAnalyzerEnabled = speechAnalyzerEnabled
  }

  public init(dictionary: [String: Any]) {
    let transcriptionMode = dictionary["transcriptionMode"] as? String
    let summaryProvider = dictionary["summaryProvider"] as? String
    let speechAnalyzerEnabled = dictionary["speechAnalyzerEnabled"] as? Bool

    if let transcriptionMode, ["local", "api"].contains(transcriptionMode) {
      self.transcriptionMode = transcriptionMode
    } else {
      self.transcriptionMode = "local"
    }

    if let summaryProvider, ["OpenAI", "Gemini", "DeepSeek", "Local"].contains(summaryProvider) {
      self.summaryProvider = summaryProvider
    } else {
      self.summaryProvider = "Gemini"
    }

    self.speechAnalyzerEnabled = speechAnalyzerEnabled ?? false
  }

  public func asDictionary() -> [String: Any] {
    [
      "transcriptionMode": transcriptionMode,
      "summaryProvider": summaryProvider,
      "speechAnalyzerEnabled": speechAnalyzerEnabled
    ]
  }
}

public protocol MemoraSettingsReadingWriting {
  var sourceDescription: String { get }

  func loadSettings() throws -> MemoraSettingsDTO
  func saveSettings(_ settings: MemoraSettingsDTO) throws
}

public enum MemoraNativeSettingsRegistry {
  public static var settingsStore: MemoraSettingsReadingWriting = MemoraUserDefaultsSettingsStore()
}

public final class MemoraSampleSettingsStore: MemoraSettingsReadingWriting {
  public let sourceDescription = "memory"
  private var settings = MemoraSettingsDTO(
    transcriptionMode: "local",
    summaryProvider: "Gemini",
    speechAnalyzerEnabled: false
  )

  public init() {}

  public func loadSettings() throws -> MemoraSettingsDTO {
    settings
  }

  public func saveSettings(_ settings: MemoraSettingsDTO) throws {
    self.settings = settings
  }
}

public final class MemoraUserDefaultsSettingsStore: MemoraSettingsReadingWriting {
  public let sourceDescription = "userdefaults"

  private let userDefaults: UserDefaults
  private let keyPrefix: String

  public init(
    userDefaults: UserDefaults = .standard,
    keyPrefix: String = "memora.reactNative.settings"
  ) {
    self.userDefaults = userDefaults
    self.keyPrefix = keyPrefix
  }

  public func loadSettings() throws -> MemoraSettingsDTO {
    MemoraSettingsDTO(dictionary: [
      "transcriptionMode": userDefaults.string(forKey: key("transcriptionMode")) ?? "local",
      "summaryProvider": userDefaults.string(forKey: key("summaryProvider")) ?? "Gemini",
      "speechAnalyzerEnabled": userDefaults.bool(forKey: key("speechAnalyzerEnabled"))
    ])
  }

  public func saveSettings(_ settings: MemoraSettingsDTO) throws {
    userDefaults.set(settings.transcriptionMode, forKey: key("transcriptionMode"))
    userDefaults.set(settings.summaryProvider, forKey: key("summaryProvider"))
    userDefaults.set(settings.speechAnalyzerEnabled, forKey: key("speechAnalyzerEnabled"))
  }

  private func key(_ name: String) -> String {
    "\(keyPrefix).\(name)"
  }
}
