import SwiftUI
import SwiftData

// MARK: - File Detail Header

struct FileDetailHeader: View {
    @Bindable var vm: FileDetailViewModel
    @FocusState var isTitleFieldFocused: Bool
    let audioFile: AudioFile
    let cachedProjectTitle: String?
    let calendarEventLink: CalendarEventLink?
    let suggestedEvent: FileDetailHelpers.EventKitEventWrapper?
    let isLinkingEvent: Bool
    let onUnlinkCalendar: () -> Void
    let onLinkSuggested: (FileDetailHelpers.EventKitEventWrapper) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            // メタ情報: date / duration (top)
            HStack(spacing: MemoraSpacing.sm) {
                Text(vm.formatDate(audioFile.createdAt))
                    .font(MemoraTypography.chatToken)
                    .foregroundStyle(MemoraColor.textTertiary)

                if audioFile.duration > 0 {
                    AccentDotIndicator(color: MemoraColor.divider, size: 4)

                    Text(vm.formatDuration(audioFile.duration))
                        .font(MemoraTypography.chatToken)
                        .foregroundStyle(MemoraColor.textTertiary)
                }

                if let projectTitle = cachedProjectTitle {
                    AccentDotIndicator(color: MemoraColor.divider, size: 4)

                    HStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(MemoraTypography.chatToken)
                            .foregroundStyle(MemoraColor.textTertiary)
                        Text(projectTitle)
                            .font(MemoraTypography.chatToken)
                            .foregroundStyle(MemoraColor.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // タイトル (bottom)
            if vm.isEditingTitle {
                TextField("タイトル", text: $vm.titleDraft)
                    .font(MemoraTypography.chatMessage)
                    .focused($isTitleFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { vm.saveTitle() }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完了") { vm.saveTitle() }
                        }
                    }
            } else {
                Button {
                    vm.beginEditTitle()
                } label: {
                    Text(audioFile.title)
                        .font(MemoraTypography.chatMessage)
                        .foregroundStyle(MemoraColor.textPrimary)
                        .lineLimit(3)
                }
                .buttonStyle(.plain)
                .accessibilityHint("タップしてタイトルを編集")
            }

            calendarEventCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Calendar Event Card

    @ViewBuilder
    private var calendarEventCard: some View {
        if let link = calendarEventLink {
            // 紐付済みイベント: clean card + left accentBlue bar
            HStack(spacing: MemoraSpacing.sm) {
                Rectangle()
                    .fill(MemoraColor.accentBlue)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(MemoraColor.accentBlue)
                    .font(MemoraTypography.chatToken)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(MemoraTypography.chatBody)
                        .foregroundStyle(MemoraColor.textPrimary)
                    Text("\(FileDetailHelpers.formatEventDate(link.startAt)) - \(FileDetailHelpers.formatEventTime(link.endAt))")
                        .font(MemoraTypography.chatToken)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
                Spacer()
                Button {
                    onUnlinkCalendar()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(MemoraColor.textTertiary)
                        .font(MemoraTypography.chatToken)
                }
            }
            .padding(MemoraSpacing.sm)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 0.5)
            )
        } else if let suggested = suggestedEvent {
            // 提案イベント: clean card + left accentBlue bar
            HStack(spacing: MemoraSpacing.sm) {
                Rectangle()
                    .fill(MemoraColor.accentBlue.opacity(0.4))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(MemoraColor.accentBlue)
                    .font(MemoraTypography.chatToken)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggested.title)
                        .font(MemoraTypography.chatBody)
                        .foregroundStyle(MemoraColor.textPrimary)
                    Text(FileDetailHelpers.formatEventDate(suggested.startDate))
                        .font(MemoraTypography.chatToken)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
                Spacer()
                Button {
                    onLinkSuggested(suggested)
                } label: {
                    if isLinkingEvent {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("紐付")
                            .font(MemoraTypography.chatButtonSmall)
                            .foregroundStyle(MemoraColor.interactivePrimaryLabel)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MemoraColor.interactivePrimary)
                            .clipShape(Capsule())
                    }
                }
                .disabled(isLinkingEvent)
            }
            .padding(MemoraSpacing.sm)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Source Badge

    @ViewBuilder
    private var sourceBadge: some View {
        let icon: String = {
            switch audioFile.sourceType {
            case .recording: return "mic.fill"
            case .import: return "square.and.arrow.down"
            case .plaud: return "waveform"
            case .google: return "video.fill"
            }
        }()
        Label({
            switch audioFile.sourceType {
            case .recording: return "録音"
            case .import: return "インポート"
            case .plaud: return "Plaud"
            case .google: return "Meet"
            }
        }(), systemImage: icon)
            .font(MemoraTypography.chatToken)
            .foregroundStyle(MemoraColor.textTertiary)
    }
}
