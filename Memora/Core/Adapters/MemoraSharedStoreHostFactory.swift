import SwiftData

/// Creates the shared audio-file adapter from the host app's ModelContainer.
/// The RN target must receive this adapter through an explicit host boundary;
/// constructing it here does not change the default bridge configuration.
@MainActor
enum MemoraSharedStoreHostFactory {
    static func makeAudioFileStore(container: ModelContainer) -> MemoraSharedAudioFileStoreAdapter {
        let context = ModelContext(container)
        let repository = AudioFileRepository(modelContext: context)
        return MemoraSharedAudioFileStoreAdapter(repository: repository)
    }
}
