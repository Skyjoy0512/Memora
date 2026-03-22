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
                SpeakerSegment.self
            ])
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
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
