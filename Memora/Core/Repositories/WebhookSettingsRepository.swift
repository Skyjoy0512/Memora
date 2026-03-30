import Foundation
import SwiftData

// MARK: - Protocol

protocol WebhookSettingsRepositoryProtocol {
    func fetch() throws -> WebhookSettings?
    func save(_ settings: WebhookSettings) throws
    func delete(_ settings: WebhookSettings) throws
}

// MARK: - Implementation

final class WebhookSettingsRepository: WebhookSettingsRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch() throws -> WebhookSettings? {
        let descriptor = FetchDescriptor<WebhookSettings>()
        return try modelContext.fetch(descriptor).first
    }

    func save(_ settings: WebhookSettings) throws {
        modelContext.insert(settings)
        try modelContext.save()
    }

    func delete(_ settings: WebhookSettings) throws {
        modelContext.delete(settings)
        try modelContext.save()
    }
}
