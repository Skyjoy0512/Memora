import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum SortOption: String, CaseIterable {
        case dateDesc = "日付（新しい順）"
        case dateAsc = "日付（古い順）"
        case titleAsc = "タイトル（昇順）"
        case titleDesc = "タイトル（降順）"
    }

    @ObservationIgnored
    private var audioFileRepository: AudioFileRepositoryProtocol?

    var audioFiles: [AudioFile] = []
    var lastErrorMessage: String?

    func configure(audioFileRepository: AudioFileRepositoryProtocol?) {
        guard self.audioFileRepository == nil else { return }
        self.audioFileRepository = audioFileRepository
    }

    func loadAudioFiles() {
        guard let audioFileRepository else { return }

        do {
            audioFiles = try audioFileRepository.fetchAll()
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
            "\\(audioFiles.count)"
        ].joined(separator: "|").hashValue

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
