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
            if vm.isEditingTitle {
                TextField("タイトル", text: $vm.titleDraft)
                    .font(MemoraTypography.phiHeadline)
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
                    HStack(spacing: MemoraSpacing.xs) {
                        Text(audioFile.title)
                            .font(MemoraTypography.phiHeadline)
                        Image(systemName: "pencil")
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("タップしてタイトルを編集")
            }

            // メタ情報: date / duration / source with AccentDotIndicator separators
            HStack(spacing: MemoraSpacing.sm) {
                Text(vm.formatDate(audioFile.createdAt))
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(.secondary)

                AccentDotIndicator(color: MemoraColor.divider, size: 4)

                if audioFile.duration > 0 {
                    Text(vm.formatDuration(audioFile.duration))
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(.secondary)

                    AccentDotIndicator(color: MemoraColor.divider, size: 4)
                }

                sourceBadge

                if let projectTitle = cachedProjectTitle {
                    AccentDotIndicator(color: MemoraColor.divider, size: 4)

                    HStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(.secondary)
                        Text(projectTitle)
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            calendarEventCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Calendar Event Card

    @ViewBuilder
    private var calendarEventCard: some View {
        if let link = calendarEventLink {
            // 紐付済みイベント: glassCard + left accentNothing bar
            HStack(spacing: MemoraSpacing.sm) {
                Rectangle()
                    .fill(MemoraColor.accentNothing)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(MemoraColor.accentNothing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(MemoraTypography.phiBody)
                        .foregroundStyle(MemoraColor.textPrimary)
                    Text("\(FileDetailHelpers.formatEventDate(link.startAt)) - \(FileDetailHelpers.formatEventTime(link.endAt))")
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
                Spacer()
                Button {
                    onUnlinkCalendar()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(MemoraColor.textSecondary)
                        .font(.caption)
                }
            }
            .padding(MemoraSpacing.sm)
            .glassCard(.default)
        } else if let suggested = suggestedEvent {
            // 提案イベント: glassCard + left accentNothing bar
            HStack(spacing: MemoraSpacing.sm) {
                Rectangle()
                    .fill(MemoraColor.accentNothing.opacity(0.4))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(MemoraColor.accentNothing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggested.title)
                        .font(MemoraTypography.phiBody)
                        .foregroundStyle(MemoraColor.textPrimary)
                    Text(FileDetailHelpers.formatEventDate(suggested.startDate))
                        .font(MemoraTypography.phiCaption)
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
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MemoraColor.accentNothing)
                            .clipShape(Capsule())
                    }
                }
                .disabled(isLinkingEvent)
            }
            .padding(MemoraSpacing.sm)
            .glassCard(.default)
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
            .font(MemoraTypography.phiCaption)
            .foregroundStyle(.secondary)
    }
}
