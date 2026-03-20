import Foundation
import SwiftData

/// SwiftData の ModelContainer を管理し、Repository に提供するシングルトンクラス
@MainActor
final class SwiftDataStack {
    static let shared = SwiftDataStack()

    private(set) lazy var modelContainer: ModelContainer = {
        do {
            let schema = Schema([
                AudioFile.self,
                Transcript.self,
                Project.self,
                MeetingNote.self,
                TodoItem.self,
                Attachment.self,
                ProcessingJob.self,
                ProcessingChunk.self
            ])
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }()

    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    private init() {}
}
