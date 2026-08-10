import Foundation

public enum MemoraExportDestination: String {
  case notion = "notion"
  case chatgpt = "chatgpt"
  case file = "file"
}

public struct MemoraExportPayloadDTO {
  public let title: String
  public let text: String
  public let createdAt: String?
  public let sourceFileId: String
  public let destination: MemoraExportDestination

  public init(dictionary: [String: Any]) {
    self.title = dictionary["title"] as? String ?? ""
    self.text = dictionary["text"] as? String ?? ""
    self.createdAt = dictionary["createdAt"] as? String
    self.sourceFileId = dictionary["sourceFileId"] as? String ?? ""
    if let destination = dictionary["destination"] as? String,
       let value = MemoraExportDestination(rawValue: destination) {
      self.destination = value
    } else {
      self.destination = .file
    }
  }
}

public struct MemoraExportResultDTO {
  public let ok: Bool
  public let destination: MemoraExportDestination
  public let refId: String?
  public let error: String?

  public init(
    ok: Bool,
    destination: MemoraExportDestination,
    refId: String? = nil,
    error: String? = nil
  ) {
    self.ok = ok
    self.destination = destination
    self.refId = refId
    self.error = error
  }

  public func asDictionary() -> [String: Any] {
    var result: [String: Any] = [
      "ok": ok,
      "destination": destination.rawValue
    ]
    if let refId {
      result["refId"] = refId
    }
    if let error {
      result["error"] = error
    }
    return result
  }
}

/// 書き出し（Notion / ChatGPT）の実処理は RN ホストのみが持つ。トークンは Keychain 側のみで扱う。
public protocol MemoraExporting {
  var sourceDescription: String { get }

  func export(_ payload: MemoraExportPayloadDTO) async throws -> MemoraExportResultDTO
}

public enum MemoraNativeExportRegistry {
  public static var exporter: MemoraExporting = MemoraUnavailableExporter()
}

public struct MemoraUnavailableExporter: MemoraExporting {
  public let sourceDescription = "native"

  public init() {}

  public func export(_ payload: MemoraExportPayloadDTO) async throws -> MemoraExportResultDTO {
    throw MemoraExportBridgeError.unavailable
  }
}

public enum MemoraExportBridgeError: LocalizedError {
  case unavailable
  case unsupportedDestination

  public var errorDescription: String? {
    switch self {
    case .unavailable:
      return "この端末では書き出し（export）を利用できません。ネイティブ接続後に有効になります。"
    case .unsupportedDestination:
      return "この書き出し先は利用できません。"
    }
  }
}
