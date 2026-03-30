import Foundation
import SwiftData
import Observation

/// 全 Repository の生成・キャッシュを行うファクトリ。
/// Environment 経由で View に注入する。
@MainActor
@Observable
final class RepositoryFactory {
    private let modelContext: ModelContext

    // Lazy-cached instances
    private var _audioFileRepo: AudioFileRepositoryProtocol?
    private var _projectRepo: ProjectRepositoryProtocol?
    private var _todoItemRepo: TodoItemRepositoryProtocol?
    private var _transcriptRepo: TranscriptRepositoryProtocol?
    private var _meetingNoteRepo: MeetingNoteRepositoryProtocol?
    private var _processingJobRepo: ProcessingJobRepositoryProtocol?
    private var _webhookSettingsRepo: WebhookSettingsRepositoryProtocol?
    private var _plaudSettingsRepo: PlaudSettingsRepositoryProtocol?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Repository Accessors

    var audioFileRepo: AudioFileRepositoryProtocol {
        if let repo = _audioFileRepo { return repo }
        let repo = AudioFileRepository(modelContext: modelContext)
        _audioFileRepo = repo
        return repo
    }

    var projectRepo: ProjectRepositoryProtocol {
        if let repo = _projectRepo { return repo }
        let repo = ProjectRepository(modelContext: modelContext)
        _projectRepo = repo
        return repo
    }

    var todoItemRepo: TodoItemRepositoryProtocol {
        if let repo = _todoItemRepo { return repo }
        let repo = TodoItemRepository(modelContext: modelContext)
        _todoItemRepo = repo
        return repo
    }

    var transcriptRepo: TranscriptRepositoryProtocol {
        if let repo = _transcriptRepo { return repo }
        let repo = TranscriptRepository(modelContext: modelContext)
        _transcriptRepo = repo
        return repo
    }

    var meetingNoteRepo: MeetingNoteRepositoryProtocol {
        if let repo = _meetingNoteRepo { return repo }
        let repo = MeetingNoteRepository(modelContext: modelContext)
        _meetingNoteRepo = repo
        return repo
    }

    var processingJobRepo: ProcessingJobRepositoryProtocol {
        if let repo = _processingJobRepo { return repo }
        let repo = ProcessingJobRepository(modelContext: modelContext)
        _processingJobRepo = repo
        return repo
    }

    var webhookSettingsRepo: WebhookSettingsRepositoryProtocol {
        if let repo = _webhookSettingsRepo { return repo }
        let repo = WebhookSettingsRepository(modelContext: modelContext)
        _webhookSettingsRepo = repo
        return repo
    }

    var plaudSettingsRepo: PlaudSettingsRepositoryProtocol {
        if let repo = _plaudSettingsRepo { return repo }
        let repo = PlaudSettingsRepository(modelContext: modelContext)
        _plaudSettingsRepo = repo
        return repo
    }
}

// MARK: - Environment Key

import SwiftUI

private struct RepositoryFactoryKey: EnvironmentKey {
    static let defaultValue: RepositoryFactory? = nil
}

extension EnvironmentValues {
    var repositoryFactory: RepositoryFactory? {
        get { self[RepositoryFactoryKey.self] }
        set { self[RepositoryFactoryKey.self] = newValue }
    }
}
