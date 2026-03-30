import Foundation
import SwiftData

// MARK: - Protocol

protocol ProcessingJobRepositoryProtocol {
    func fetch(id: UUID) throws -> ProcessingJob?
    func fetchActive() throws -> [ProcessingJob]
    func save(_ job: ProcessingJob) throws
    func delete(_ job: ProcessingJob) throws
    func updateStatus(_ job: ProcessingJob, status: String, progress: Double, error: String?) throws
}

// MARK: - Implementation

final class ProcessingJobRepository: ProcessingJobRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch(id: UUID) throws -> ProcessingJob? {
        let descriptor = FetchDescriptor<ProcessingJob>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchActive() throws -> [ProcessingJob] {
        let descriptor = FetchDescriptor<ProcessingJob>(
            predicate: #Predicate { $0.status == "running" || $0.status == "pending" }
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ job: ProcessingJob) throws {
        modelContext.insert(job)
        try modelContext.save()
    }

    func delete(_ job: ProcessingJob) throws {
        modelContext.delete(job)
        try modelContext.save()
    }

    func updateStatus(_ job: ProcessingJob, status: String, progress: Double, error: String? = nil) throws {
        job.status = status
        job.progress = progress
        job.error = error

        switch status {
        case "running":
            job.startedAt = Date()
        case "completed", "failed":
            job.completedAt = Date()
        default:
            break
        }

        try modelContext.save()
    }
}
