import Foundation

public struct MemoraTaskDTO {
  public let id: String
  public let title: String
  public let notes: String?
  public let assignee: String?
  public let speaker: String?
  public let priority: String
  public let dueDate: String?
  public let relativeDueDate: String?
  public let projectID: String?
  public let parentID: String?
  public let sourceAudioFileID: String?
  public let isCompleted: Bool
  public let createdAt: String
  public let completedAt: String?

  public init(
    id: String,
    title: String,
    notes: String? = nil,
    assignee: String? = nil,
    speaker: String? = nil,
    priority: String = "medium",
    dueDate: String? = nil,
    relativeDueDate: String? = nil,
    projectID: String? = nil,
    parentID: String? = nil,
    sourceAudioFileID: String? = nil,
    isCompleted: Bool = false,
    createdAt: String,
    completedAt: String? = nil
  ) {
    self.id = id
    self.title = title
    self.notes = notes
    self.assignee = assignee
    self.speaker = speaker
    self.priority = priority
    self.dueDate = dueDate
    self.relativeDueDate = relativeDueDate
    self.projectID = projectID
    self.parentID = parentID
    self.sourceAudioFileID = sourceAudioFileID
    self.isCompleted = isCompleted
    self.createdAt = createdAt
    self.completedAt = completedAt
  }

  public init(dictionary: [String: Any]) {
    id = dictionary["id"] as? String ?? UUID().uuidString
    title = dictionary["title"] as? String ?? ""
    notes = dictionary["notes"] as? String
    assignee = dictionary["assignee"] as? String
    speaker = dictionary["speaker"] as? String
    priority = dictionary["priority"] as? String ?? "medium"
    dueDate = dictionary["dueDate"] as? String
    relativeDueDate = dictionary["relativeDueDate"] as? String
    projectID = dictionary["projectId"] as? String
    parentID = dictionary["parentId"] as? String
    sourceAudioFileID = dictionary["sourceAudioFileId"] as? String
    isCompleted = dictionary["isCompleted"] as? Bool ?? false
    createdAt = dictionary["createdAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
    completedAt = dictionary["completedAt"] as? String
  }

  public func asDictionary() -> [String: Any] {
    [
      "id": id,
      "title": title,
      "notes": notes ?? NSNull(),
      "assignee": assignee ?? NSNull(),
      "speaker": speaker ?? NSNull(),
      "priority": priority,
      "dueDate": dueDate ?? NSNull(),
      "relativeDueDate": relativeDueDate ?? NSNull(),
      "projectId": projectID ?? NSNull(),
      "parentId": parentID ?? NSNull(),
      "sourceAudioFileId": sourceAudioFileID ?? NSNull(),
      "isCompleted": isCompleted,
      "createdAt": createdAt,
      "completedAt": completedAt ?? NSNull()
    ]
  }
}

public protocol MemoraTaskReading {
  var sourceDescription: String { get }

  func listTasks() throws -> [MemoraTaskDTO]
}

public protocol MemoraTaskMutating {
  var sourceDescription: String { get }

  func createTask(_ dto: MemoraTaskDTO) throws -> MemoraTaskDTO
  func updateTask(_ dto: MemoraTaskDTO) throws -> MemoraTaskDTO?
  func toggleTask(id: String, completed: Bool) throws -> MemoraTaskDTO?
  func deleteTask(id: String) throws -> Bool
}

public enum MemoraNativeTaskReaderRegistry {
  public static var taskReader: MemoraTaskReading = MemoraNativeInMemoryTaskStore()
}

public enum MemoraNativeTaskMutationRegistry {
  public static var taskMutator: MemoraTaskMutating = MemoraNativeInMemoryTaskStore()
}

public final class MemoraNativeInMemoryTaskStore: MemoraTaskReading, MemoraTaskMutating {
  public let sourceDescription = "memory"
  private let lock = NSLock()
  private var tasks: [MemoraTaskDTO] = []

  public init() {}

  public func listTasks() throws -> [MemoraTaskDTO] {
    lock.lock()
    defer { lock.unlock() }
    return tasks
  }

  public func createTask(_ dto: MemoraTaskDTO) throws -> MemoraTaskDTO {
    lock.lock()
    defer { lock.unlock() }
    tasks.insert(dto, at: 0)
    return dto
  }

  public func updateTask(_ dto: MemoraTaskDTO) throws -> MemoraTaskDTO? {
    lock.lock()
    defer { lock.unlock() }
    guard let index = tasks.firstIndex(where: { $0.id == dto.id }) else {
      return nil
    }
    tasks[index] = dto
    return dto
  }

  public func toggleTask(id: String, completed: Bool) throws -> MemoraTaskDTO? {
    lock.lock()
    defer { lock.unlock() }
    guard let index = tasks.firstIndex(where: { $0.id == id }) else {
      return nil
    }
    let current = tasks[index]
    let updated = MemoraTaskDTO(
      id: current.id,
      title: current.title,
      notes: current.notes,
      assignee: current.assignee,
      speaker: current.speaker,
      priority: current.priority,
      dueDate: current.dueDate,
      relativeDueDate: current.relativeDueDate,
      projectID: current.projectID,
      parentID: current.parentID,
      sourceAudioFileID: current.sourceAudioFileID,
      isCompleted: completed,
      createdAt: current.createdAt,
      completedAt: completed ? ISO8601DateFormatter().string(from: Date()) : nil
    )
    tasks[index] = updated
    return updated
  }

  public func deleteTask(id: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let previousCount = tasks.count
    tasks.removeAll { $0.id == id }
    return tasks.count != previousCount
  }
}
