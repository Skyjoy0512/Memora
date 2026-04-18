import SwiftUI

// MARK: - File Detail Helpers

struct FileDetailHelpers {
    /// EKEvent の軽量ラッパー（@State で保持するため）
    struct EventKitEventWrapper {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
    }

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()

    private static let eventTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static func formatEventDate(_ date: Date) -> String {
        eventDateFormatter.string(from: date)
    }

    static func formatEventTime(_ date: Date) -> String {
        eventTimeFormatter.string(from: date)
    }

    @MainActor
    static func memoStatusText(vm: FileDetailViewModel) -> String {
        if vm.memoHasUnsavedChanges {
            return "未保存の変更があります"
        }

        if let updatedAt = vm.memoUpdatedAt {
            return "最終保存: \(vm.formatDate(updatedAt))"
        }

        return "まだメモは保存されていません"
    }

    static func thumbnailImage(for attachment: PhotoAttachment) -> UIImage? {
        if let thumbnailPath = attachment.thumbnailPath,
           let image = UIImage(contentsOfFile: thumbnailPath) {
            return image
        }

        return UIImage(contentsOfFile: attachment.localPath)
    }

    static func fullSizeImage(for attachment: PhotoAttachment) -> UIImage? {
        UIImage(contentsOfFile: attachment.localPath)
    }

    @ViewBuilder
    static func memoThumbnail(for attachment: PhotoAttachment) -> some View {
        if let image = thumbnailImage(for: attachment) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: MemoraRadius.md)
                    .fill(MemoraColor.divider.opacity(0.16))
                Image(systemName: "photo")
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
    }
}
