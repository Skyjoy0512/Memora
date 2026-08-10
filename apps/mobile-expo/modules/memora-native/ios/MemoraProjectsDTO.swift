import Foundation

public struct MemoraProjectDTO {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }

  public func asDictionary() -> [String: Any] {
    [
      "id": id,
      "title": title
    ]
  }
}

public protocol MemoraProjectReading {
  var sourceDescription: String { get }

  func listProjects() throws -> [MemoraProjectDTO]
}

public enum MemoraNativeProjectReaderRegistry {
  public static var projectReader: MemoraProjectReading = MemoraNativeInMemoryProjectStore()
}

public final class MemoraNativeInMemoryProjectStore: MemoraProjectReading {
  public let sourceDescription = "memory"

  public init() {}

  public func listProjects() throws -> [MemoraProjectDTO] {
    []
  }
}
