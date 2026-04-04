import Testing
import Foundation
@testable import Memora

struct ProcessingJobTests {

    // MARK: - canRetry Logic

    @Test("canRetry は retryCount < maxRetries の場合 true を返す")
    func canRetryWhenUnderLimit() {
        let job = ProcessingJob(audioFileID: UUID(), jobType: "transcription")
        job.retryCount = 0
        job.maxRetries = 1
        #expect(job.canRetry == true)
    }

    @Test("canRetry は retryCount >= maxRetries の場合 false を返す")
    func canRetryWhenAtLimit() {
        let job = ProcessingJob(audioFileID: UUID(), jobType: "transcription")
        job.retryCount = 1
        job.maxRetries = 1
        #expect(job.canRetry == false)
    }

    @Test("canRetry は maxRetries=3 の場合複数リトライを許容する")
    func canRetryMultipleAttempts() {
        let job = ProcessingJob(audioFileID: UUID(), jobType: "transcription")
        job.maxRetries = 3

        job.retryCount = 0
        #expect(job.canRetry == true)

        job.retryCount = 2
        #expect(job.canRetry == true)

        job.retryCount = 3
        #expect(job.canRetry == false)
    }

    // MARK: - Status Helpers

    @Test("markStarted は status と stage を更新する")
    func markStartedUpdatesStatus() {
        let job = ProcessingJob(audioFileID: UUID(), jobType: "transcription")
        #expect(job.status == "pending")
        #expect(job.startedAt == nil)

        job.markStarted(stage: "transcribing")

        #expect(job.status == "running")
        #expect(job.startedAt != nil)
        #expect(job.stage == "transcribing")
    }

    @Test("updateProgress は progress と stage を更新する")
    func updateProgressUpdatesValues() {
        let job = ProcessingJob(audioFileID: UUID(), jobType: "transcription")

        job.updateProgress(0.5, stage: "summarizing")

        #expect(job.progress == 0.5)
        #expect(job.stage == "summarizing")
    }

    @Test("markCompleted は status と progress を更新する")
    func markCompletedUpdatesStatus() {
        let job = ProcessingJob(audioFileID: UUID(), jobType: "transcription")
        job.markStarted(stage: "transcribing")
        job.updateProgress(0.7, stage: "processing")

        job.markCompleted()

        #expect(job.status == "completed")
        #expect(job.progress == 1.0)
        #expect(job.completedAt != nil)
    }

    @Test("markFailed は status と error を更新する")
    func markFailedUpdatesStatus() {
        let job = ProcessingJob(audioFileID: UUID(), jobType: "transcription")
        job.markStarted(stage: "transcribing")

        job.markFailed("network timeout", stage: "api_call")

        #expect(job.status == "failed")
        #expect(job.error == "network timeout")
        #expect(job.stage == "api_call")
    }

    // MARK: - Default Values

    @Test("ProcessingJob のデフォルト値が正しい")
    func defaultValues() {
        let fileID = UUID()
        let job = ProcessingJob(audioFileID: fileID, jobType: "transcription")

        #expect(job.audioFileID == fileID)
        #expect(job.jobType == "transcription")
        #expect(job.status == "pending")
        #expect(job.progress == 0)
        #expect(job.error == nil)
        #expect(job.startedAt == nil)
        #expect(job.completedAt == nil)
        #expect(job.stage == "none")
        #expect(job.retryCount == 0)
        #expect(job.maxRetries == 1)
    }
}
