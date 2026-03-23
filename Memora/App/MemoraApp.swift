import SwiftUI
import SwiftData

@main
struct MemoraApp: App {
    let modelContainer: ModelContainer = {
        do {
            let schema = Schema([
                AudioFile.self,
                Transcript.self,
                Project.self,
                MeetingNote.self,
                TodoItem.self,
                ProcessingJob.self,
                WebhookSettings.self,
                PlaudSettings.self
            ])
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false, allowsSave: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
