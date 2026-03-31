import Testing
import Foundation
import SwiftData
@testable import Memora

@MainActor
struct FileDetailViewModelTests {

    // MARK: - Format Helpers

    @Test("formatDate が正しいフォーマットを出力する")
    func formatDate() {
        let vm = makeViewModel()
        let date = DateComponents(
            calendar: .current,
            year: 2026, month: 3, day: 15,
            hour: 14, minute: 30
        ).date!

        let formatted = vm.formatDate(date)
        #expect(formatted.contains("2026"))
        #expect(formatted.contains("03"))
        #expect(formatted.contains("15"))
    }

    @Test("formatDuration が分:秒フォーマットを出力する")
    func formatDuration() {
        let vm = makeViewModel()

        #expect(vm.formatDuration(0) == "0:00")
        #expect(vm.formatDuration(59) == "0:59")
        #expect(vm.formatDuration(60) == "1:00")
        #expect(vm.formatDuration(125) == "2:05")
        #expect(vm.formatDuration(3600) == "60:00")
    }

    @Test("formatTime が分:秒フォーマットを出力する")
    func formatTime() {
        let vm = makeViewModel()

        #expect(vm.formatTime(0) == "0:00")
        #expect(vm.formatTime(90) == "1:30")
        #expect(vm.formatTime(45) == "0:45")
    }

    // MARK: - Initial State

    @Test("初期状態が正しい")
    func initialState() {
        let vm = makeViewModel()

        #expect(vm.isPlaying == false)
        #expect(vm.playbackPosition == 0)
        #expect(vm.audioDuration == 0)
        #expect(vm.audioURL == nil)
        #expect(vm.isTranscribing == false)
        #expect(vm.transcriptionProgress == 0)
        #expect(vm.isSummarizing == false)
        #expect(vm.summarizationProgress == 0)
        #expect(vm.transcriptResult == nil)
        #expect(vm.summaryResult == nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.showErrorAlert == false)
        #expect(vm.successMessage == nil)
        #expect(vm.showSuccessAlert == false)
        #expect(vm.showTranscriptView == false)
        #expect(vm.showSummaryView == false)
        #expect(vm.showShareSheet == false)
        #expect(vm.showGenerationFlow == false)
        #expect(vm.showDeleteAlert == false)
    }

    @Test("audioFile が正しく保持される")
    func retainsAudioFile() {
        let vm = makeViewModel()
        #expect(vm.audioFile.title == "テスト")
        #expect(vm.audioFile.audioURL == "/tmp/test.m4a")
    }

    // MARK: - Audio URL Setup

    @Test("setupAudioPlayer が絶対パスを正しく処理する")
    func setupAudioPlayerAbsolutePath() {
        let vm = makeViewModel(audioURLPath: "/var/mobile/test.m4a")
        vm.setupAudioPlayer()

        #expect(vm.audioURL != nil)
        #expect(vm.audioURL?.path == "/var/mobile/test.m4a")
    }

    @Test("setupAudioPlayer が file:// プレフィックスを処理する")
    func setupAudioPlayerFilePrefix() {
        let vm = makeViewModel(audioURLPath: "file:///var/mobile/test.m4a")
        vm.setupAudioPlayer()

        #expect(vm.audioURL != nil)
        #expect(vm.audioURL?.path == "/var/mobile/test.m4a")
    }

    @Test("setupAudioPlayer が空パスでURLをnilに保つ")
    func setupAudioPlayerEmptyPath() {
        let vm = makeViewModel(audioURLPath: "")
        vm.setupAudioPlayer()

        #expect(vm.audioURL == nil)
    }

    // MARK: - Cleanup

    @Test("cleanup が再生を停止する")
    func cleanupStopsPlayback() {
        let vm = makeViewModel()
        vm.isPlaying = true
        vm.cleanup()

        #expect(vm.isPlaying == false)
    }

    // MARK: - Helpers

    private func makeViewModel(audioURLPath: String = "/tmp/test.m4a") -> FileDetailViewModel {
        let audioFile = AudioFile(title: "テスト", audioURL: audioURLPath)
        let repoFactory = RepositoryFactory(modelContext: mockModelContext)
        return FileDetailViewModel(
            audioFile: audioFile,
            repoFactory: repoFactory,
            provider: .openai,
            transcriptionMode: .local,
            apiKey: "test-key"
        )
    }

    private var mockModelContext: ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: AudioFile.self,
            Transcript.self,
            TodoItem.self,
            Project.self,
            MeetingNote.self,
            ProcessingJob.self,
            WebhookSettings.self,
            PlaudSettings.self,
            configurations: config
        )
        return container.mainContext
    }
}
