import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    static let pageSize = 50

    enum SortOption: String, CaseIterable {
        case dateDesc = "日付（新しい順）"
        case dateAsc = "日付（古い順）"
        case titleAsc = "タイトル（昇順）"
        case titleDesc = "タイトル（降順）"
    }

    @ObservationIgnored
    private var audioFileRepository: AudioFileRepositoryProtocol?

    var audioFiles: [AudioFile] = [] {
        didSet { filterCacheInvalidated = true }
    }
    var lastErrorMessage: String?
    private(set) var hasMoreAudioFiles = false
    private(set) var isLoadingMoreAudioFiles = false

    @ObservationIgnored private var filterCacheInvalidated = true
    @ObservationIgnored private var cachedFilterHash: Int = 0
    @ObservationIgnored private var cachedFilteredResult: [AudioFile] = []

    func configure(audioFileRepository: AudioFileRepositoryProtocol?) {
        guard self.audioFileRepository == nil else { return }
        self.audioFileRepository = audioFileRepository
    }

    func loadAudioFiles() {
        guard let audioFileRepository else { return }

        do {
            let firstPage = try audioFileRepository.fetchPage(offset: 0, limit: Self.pageSize)
            audioFiles = firstPage
            hasMoreAudioFiles = firstPage.count == Self.pageSize
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func loadMoreAudioFilesIfNeeded(currentFile: AudioFile? = nil) {
        guard hasMoreAudioFiles, !isLoadingMoreAudioFiles, let audioFileRepository else { return }

        if let currentFile {
            let thresholdIndex = audioFiles.index(audioFiles.endIndex, offsetBy: -5, limitedBy: audioFiles.startIndex) ?? audioFiles.startIndex
            guard audioFiles.firstIndex(where: { $0.id == currentFile.id }).map({ $0 >= thresholdIndex }) == true else {
                return
            }
        }

        isLoadingMoreAudioFiles = true
        defer { isLoadingMoreAudioFiles = false }

        do {
            let nextPage = try audioFileRepository.fetchPage(offset: audioFiles.count, limit: Self.pageSize)
            let existingIDs = Set(audioFiles.map(\.id))
            audioFiles.append(contentsOf: nextPage.filter { !existingIDs.contains($0.id) })
            hasMoreAudioFiles = nextPage.count == Self.pageSize
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteAudioFiles(at offsets: IndexSet, from visibleFiles: [AudioFile]) {
        for index in offsets {
            let file = visibleFiles[index]
            delete(file)
        }
    }

    func audioFile(id: UUID?) -> AudioFile? {
        guard let id else { return nil }
        return audioFiles.first(where: { $0.id == id })
    }

    func filteredFiles(
        searchText: String,
        filterTranscribed: Bool?,
        filterSummarized: Bool?,
        filterLifeLog: Bool?,
        selectedTag: String?,
        sortOption: SortOption
    ) -> [AudioFile] {
        let hash = [
            searchText,
            filterTranscribed?.description,
            filterSummarized?.description,
            filterLifeLog?.description,
            selectedTag,
            sortOption.rawValue,
            "\(audioFiles.count)",
            "\(hasMoreAudioFiles)"
        ].compactMap { $0 }.joined(separator: "|").hashValue

        if !filterCacheInvalidated && hash == cachedFilterHash {
            return cachedFilteredResult
        }

        var files = audioFiles

        if !searchText.isEmpty {
            files = files.filter { $0.title.localizedStandardContains(searchText) }
        }

        if let filterTranscribed {
            files = files.filter { $0.isTranscribed == filterTranscribed }
        }

        if let filterSummarized {
            files = files.filter { $0.isSummarized == filterSummarized }
        }

        if let filterLifeLog {
            files = files.filter { $0.isLifeLog == filterLifeLog }
        }

        if let selectedTag, !selectedTag.isEmpty {
            files = files.filter { $0.lifeLogTags.contains(selectedTag) }
        }

        switch sortOption {
        case .dateDesc:
            files.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:
            files.sort { $0.createdAt < $1.createdAt }
        case .titleAsc:
            files.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleDesc:
            files.sort { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        }

        cachedFilteredResult = files
        cachedFilterHash = hash
        filterCacheInvalidated = false
        return files
    }

    private func delete(_ file: AudioFile) {
        guard let audioFileRepository else { return }

        do {
            try audioFileRepository.delete(file)
            audioFiles.removeAll(where: { $0.id == file.id })
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
