import Foundation
import SwiftData

// MARK: - Protocol

protocol PlaudSettingsRepositoryProtocol {
    func fetch() throws -> PlaudSettings?
    func save(_ settings: PlaudSettings) throws
    func delete(_ settings: PlaudSettings) throws
}

// MARK: - Implementation

final class PlaudSettingsRepository: PlaudSettingsRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch() throws -> PlaudSettings? {
        let descriptor = FetchDescriptor<PlaudSettings>()
        return try modelContext.fetch(descriptor).first
    }

    func save(_ settings: PlaudSettings) throws {
        modelContext.insert(settings)
        try modelContext.save()
    }

    func delete(_ settings: PlaudSettings) throws {
        modelContext.delete(settings)
        try modelContext.save()
    }
}
