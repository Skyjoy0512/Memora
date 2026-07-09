import SwiftUI
import SwiftData

enum V6HomeFilter {
    case files
    case projects
    case lifelog
}

struct V6AppShellView: View {
    @Binding var selectedTab: Int
    @Binding var showPaywall: Bool
    let onStartRecording: () -> Void
    let onImport: () -> Void
    let onMeetingCapture: () -> Void
    let onOpenFileDetail: (AudioFile) -> Void

    @AppStorage(V6AuthStorageKey.isPro) private var isPro = false
    @AppStorage(V6AuthStorageKey.loginEmail) private var loginEmail = ""
    @Query(sort: \AudioFile.createdAt, order: .reverse) private var audioFiles: [AudioFile]
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todos: [TodoItem]
    @State private var isFabMenuOpen = false
    @State private var homeFilter: V6HomeFilter = .files
    @State private var isHomeFilterMenuOpen = false
    @State private var lifelogDayOffset = 0
    @State private var fileMoreMenuTarget: AudioFile?
    @State private var fileRenameTarget: AudioFile?
    @State private var fileRenameDraft = ""
    @State private var fileMoveTarget: AudioFile?
    @State private var fileMoveSelection: Project?
    @State private var fileDeleteTarget: AudioFile?
    @State private var selectedProject: Project?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BluetoothAudioService.self) private var bluetoothService
    @Environment(\.modelContext) private var modelContext

    private var overdueTaskCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return todos.filter { !$0.isCompleted && ($0.dueDate.map { $0 < startOfToday } ?? false) }.count
    }

    private var homeTitleLabel: String {
        switch homeFilter {
        case .files: "全ファイル"
        case .projects: "プロジェクト"
        case .lifelog: "ライフログ"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            V6Color.white.ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    homeScreen
                case 1:
                    tasksScreen
                case 2:
                    askScreen
                default:
                    settingsScreen
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isFabMenuOpen {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { isFabMenuOpen = false }
            }

            VStack(alignment: .trailing, spacing: 12) {
                if isFabMenuOpen {
                    V6FabMenu(
                        onRecord: {
                            isFabMenuOpen = false
                            onStartRecording()
                        },
                        onImport: {
                            isFabMenuOpen = false
                            onImport()
                        },
                        onMeetingCapture: {
                            isFabMenuOpen = false
                            onMeetingCapture()
                        }
                    )
                }

                HStack(spacing: 10) {
                    V6GlassTabBar(selectedTab: $selectedTab, tasksBadgeCount: overdueTaskCount)
                    V6FabButton(isOpen: isFabMenuOpen) {
                        isFabMenuOpen.toggle()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFabMenuOpen)
        .onChange(of: selectedTab) { _, _ in
            isFabMenuOpen = false
            showPaywall = false
        }
        .sheet(isPresented: $showPaywall) {
            V6PaywallSheet(isPro: $isPro)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var homeScreen: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        selectedTab = 3
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "waveform")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(V6Color.ink)
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(bluetoothService.isConnected ? V6Color.success : V6Color.neutralBorder)
                                .frame(width: 6, height: 6)
                            Text(bluetoothService.isConnected ? (bluetoothService.connectedDeviceName ?? "デバイス") : "接続 ›")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(V6Color.ink)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(V6Color.quiet)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 18) {
                        Button { selectedTab = 2 } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 19, weight: .regular))
                                .foregroundStyle(V6Color.ink)
                        }
                        Button { selectedTab = 3 } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 19, weight: .regular))
                                .foregroundStyle(V6Color.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)

                Button {
                    isHomeFilterMenuOpen = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(homeTitleLabel)
                            .font(V6Font.title)
                            .tracking(V6Tracking.title)
                            .foregroundStyle(V6Color.ink)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(V6Color.muted)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                switch homeFilter {
                case .files:
                    filesSegment
                case .projects:
                    projectsSegment
                case .lifelog:
                    lifelogSegment
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 104)
        }
        .navigationDestination(item: $selectedProject) { project in
            ProjectDetailView(project: project)
                .toolbar(.hidden, for: .tabBar)
        }
        .sheet(isPresented: $isHomeFilterMenuOpen) {
            V6HomeFilterSheet(selection: $homeFilter)
                .presentationDetents([.height(240)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $fileMoreMenuTarget) { file in
            V6FileMoreSheet(
                onRename: {
                    fileRenameDraft = file.title
                    fileRenameTarget = file
                    fileMoreMenuTarget = nil
                },
                onMove: {
                    fileMoveSelection = projects.first(where: { $0.id == file.projectID })
                    fileMoveTarget = file
                    fileMoreMenuTarget = nil
                },
                onDelete: {
                    fileDeleteTarget = file
                    fileMoreMenuTarget = nil
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .alert("タイトルを変更", isPresented: Binding(
            get: { fileRenameTarget != nil },
            set: { if !$0 { fileRenameTarget = nil } }
        )) {
            TextField("ファイル名", text: $fileRenameDraft)
            Button("キャンセル", role: .cancel) { fileRenameTarget = nil }
            Button("保存") {
                if let file = fileRenameTarget, !fileRenameDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                    file.title = fileRenameDraft
                    try? modelContext.save()
                }
                fileRenameTarget = nil
            }
        }
        .sheet(item: $fileMoveTarget) { file in
            ProjectPickerSheet(projects: projects, selectedProject: $fileMoveSelection)
                .onDisappear {
                    file.projectID = fileMoveSelection?.id
                    try? modelContext.save()
                }
        }
        .overlay {
            if let file = fileDeleteTarget {
                V6DeleteConfirmOverlay(
                    onCancel: { fileDeleteTarget = nil },
                    onConfirm: {
                        modelContext.delete(file)
                        try? modelContext.save()
                        fileDeleteTarget = nil
                    }
                )
            }
        }
    }

    private var todayFiles: [AudioFile] {
        audioFiles.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var weekFiles: [AudioFile] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: startOfToday) else { return [] }
        return audioFiles.filter { !Calendar.current.isDateInToday($0.createdAt) && $0.createdAt >= weekAgo }
    }

    private var earlierFiles: [AudioFile] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: startOfToday) else { return [] }
        return audioFiles.filter { $0.createdAt < weekAgo }
    }

    @ViewBuilder
    private var filesSegment: some View {
        if audioFiles.isEmpty {
            V6EmptyHomeView(onStartRecording: onStartRecording)
                .frame(maxWidth: .infinity)
                .padding(.top, 110)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !todayFiles.isEmpty {
                    V6SectionLabel("今日")
                    ForEach(todayFiles) { file in
                        fileRow(file)
                    }
                }
                if !weekFiles.isEmpty {
                    V6SectionLabel("今週").padding(.top, 14)
                    ForEach(weekFiles) { file in
                        fileRow(file)
                    }
                }
                if !earlierFiles.isEmpty {
                    V6SectionLabel("以前").padding(.top, 14)
                    ForEach(earlierFiles) { file in
                        fileRow(file)
                    }
                }
            }
            .padding(.top, 18)
        }
    }

    private func fileRow(_ file: AudioFile) -> some View {
        V6FileRow(
            file: file,
            job: latestJob(for: file),
            onOpen: { onOpenFileDetail(file) },
            onRetry: { onOpenFileDetail(file) },
            onMore: { fileMoreMenuTarget = file }
        )
    }

    private func latestJob(for file: AudioFile) -> ProcessingJob? {
        file.processingJobs.max(by: { ($0.startedAt ?? $0.createdAt) < ($1.startedAt ?? $1.createdAt) })
    }

    @ViewBuilder
    private var projectsSegment: some View {
        if projects.isEmpty {
            V6EmptyStateLabel(text: "プロジェクトはまだありません")
                .padding(.top, 110)
        } else {
            V6ProjectsGrid(projects: projects, audioFiles: audioFiles) { project in
                selectedProject = project
            }
            .padding(.top, 18)
            .padding(.bottom, 110)
        }
    }

    private var lifelogSelectedDate: Date {
        Calendar.current.date(byAdding: .day, value: lifelogDayOffset, to: Date()) ?? Date()
    }

    private var lifelogMoments: [AudioFile] {
        audioFiles
            .filter { $0.isLifeLog && Calendar.current.isDate($0.createdAt, inSameDayAs: lifelogSelectedDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var lifelogHighlights: [AudioFile] {
        lifelogMoments.filter { $0.lifeLogTags.contains("highlight") }
    }

    private var lifelogDayLabel: String {
        if lifelogDayOffset == 0 { return "今日" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: lifelogSelectedDate)
    }

    private var lifelogSegment: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 15))
                    .foregroundStyle(V6Color.ink)
                Circle()
                    .fill(bluetoothService.isConnected ? V6Color.success : V6Color.neutralBorder)
                    .frame(width: 7, height: 7)
                Text(bluetoothService.isConnected ? (bluetoothService.connectedDeviceName ?? "デバイス") + " 接続中" : "未接続")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V6Color.ink)
                Spacer()
                if let battery = bluetoothService.batteryLevel {
                    Text("\(battery)%")
                        .font(.system(size: 12))
                        .foregroundStyle(V6Color.muted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(V6Color.faint, in: RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous))
            .padding(.bottom, 16)

            if !lifelogHighlights.isEmpty {
                V6SectionLabel("ハイライト").padding(.bottom, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lifelogHighlights) { moment in
                            V6LifelogHighlightCard(file: moment) { onOpenFileDetail(moment) }
                        }
                    }
                }
                .padding(.bottom, 20)
            }

            HStack {
                Button { lifelogDayOffset -= 1 } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(V6Color.ink)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Spacer()
                Text("\(lifelogDayLabel)のタイムライン")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(V6Color.quiet)
                Spacer()

                Button { lifelogDayOffset += 1 } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(lifelogDayOffset < 0 ? V6Color.ink : V6Color.neutralBorder)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(lifelogDayOffset >= 0)
            }
            .padding(.bottom, 4)

            if lifelogMoments.isEmpty {
                V6EmptyStateLabel(text: "この日の記録はありません")
                    .padding(.top, 60)
            } else {
                ForEach(lifelogMoments) { moment in
                    V6LifelogMomentRow(file: moment) { onOpenFileDetail(moment) }
                }
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 110)
    }

    private var tasksScreen: some View {
        V6PlainScreen(title: "タスク") {
            VStack(alignment: .leading, spacing: 0) {
                V6SectionLabel("今日")
                if todos.isEmpty {
                    V6TaskRow(title: "プロダクト方針を確認する", source: "プロダクト定例MTG", done: false)
                    V6TaskRow(title: "次回インタビュー候補をまとめる", source: "ユーザーインタビュー", done: false)
                } else {
                    ForEach(todos.prefix(8)) { todo in
                        V6TaskRow(title: todo.title, source: projectTitle(for: todo.projectID), done: todo.isCompleted)
                    }
                }
            }
        }
    }

    private var askScreen: some View {
        V6PlainScreen(title: "Ask") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Text("先週決まったことは？")
                        .font(.system(size: 13))
                        .foregroundStyle(V6Color.muted)
                    Spacer()
                }
                .padding(14)
                .background(V6Color.soft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("プロダクト定例では、録音後の生成導線を短くし、File Detail に要約・文字起こし・メモを集約する方針が確認されています。")
                        .font(.system(size: 15))
                        .lineSpacing(6)
                        .foregroundStyle(V6Color.ink)
                    HStack(spacing: 8) {
                        V6CitationChip("プロダクト定例MTG")
                        V6CitationChip("ユーザーインタビュー")
                    }
                }
            }
        }
    }

    private var settingsScreen: some View {
        V6PlainScreen(title: "設定") {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    V6SettingsRow(title: "プラン", value: isPro ? "Pro" : "Free", leading: "sparkles") {
                        showPaywall = true
                    }
                    V6SettingsRow(title: "ログイン", value: loginEmail.isEmpty ? "未設定" : loginEmail, leading: "person.crop.circle") {}
                }

                VStack(spacing: 0) {
                    V6SettingsRow(title: "文字起こし", value: "ChatGPT-5", leading: "waveform") {}
                    V6SettingsRow(title: "通知", value: "オン", leading: "bell") {}
                    V6SettingsRow(title: "デバイス連携", value: bluetoothService.isConnected ? "接続済み" : "未接続", leading: "dot.radiowaves.left.and.right") {}
                    V6SettingsRow(title: "データ管理", value: "", leading: "externaldrive") {}
                }

                Button {
                    isPro = false
                    loginEmail = ""
                } label: {
                    Text("ログアウト")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(V6Color.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func projectTitle(for projectID: UUID?) -> String {
        guard let projectID else { return "Memora" }
        return projects.first(where: { $0.id == projectID })?.title ?? "Memora"
    }
}

private struct V6EmptyHomeView: View {
    let onStartRecording: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onStartRecording) {
                ZStack {
                    Circle().fill(V6Color.ink)
                    Circle().fill(V6Color.danger).frame(width: 26, height: 26)
                }
                .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                Text("最初の録音をはじめる")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(V6Color.ink)
                Text("会議や雑談をタップひとつで記録し、要約とタスクを自動で作成します。")
                    .font(.system(size: 13))
                    .lineSpacing(6)
                    .foregroundStyle(V6Color.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
            }
        }
    }
}

private struct V6FileRow: View {
    let file: AudioFile
    let job: ProcessingJob?
    let onOpen: () -> Void
    let onRetry: () -> Void
    let onMore: () -> Void

    private var isProcessing: Bool {
        job?.status == "pending" || job?.status == "running"
    }

    private var isFailed: Bool {
        job?.status == "failed"
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.title)
                            .font(V6Font.rowTitle)
                            .foregroundStyle(V6Color.ink)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if isProcessing {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                            Text(fileMeta)
                                .font(.system(size: 12))
                                .foregroundStyle(isFailed ? V6Color.danger : V6Color.quiet)
                        }
                    }
                    Spacer()
                    if isFailed {
                        Button("再試行", action: onRetry)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(V6Color.ink)
                            .underline()
                            .buttonStyle(.plain)
                    } else if !isProcessing {
                        Button(action: onMore) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: "D1D1D6"))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isProcessing, let job {
                    ProgressView(value: job.progress)
                        .tint(V6Color.ink)
                }

                if let summary = file.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12.5))
                        .lineSpacing(5)
                        .foregroundStyle(V6Color.muted)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fileMeta: String {
        if isFailed { return "文字起こしに失敗しました" }
        let minutes = Int(file.duration / 60)
        let duration = minutes > 0 ? "\(minutes)分" : "未処理"
        return "\(duration) ・ \(file.isSummarized ? "要約済み" : "処理待ち")"
    }
}

private struct V6EmptyStateLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(V6Color.muted)
            .frame(maxWidth: .infinity)
    }
}

private struct V6ProjectsGrid: View {
    let projects: [Project]
    let audioFiles: [AudioFile]
    let onOpen: (Project) -> Void

    private let palette: [Color] = [
        Color(hex: "0D0D0D"), Color(hex: "6E6E80"), Color(hex: "8E8EA0"), Color(hex: "3A3A3C")
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            ForEach(projects) { project in
                Button {
                    onOpen(project)
                } label: {
                    VStack(alignment: .leading, spacing: 28) {
                        Text(String(project.title.prefix(1)))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(color(for: project), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(V6Color.ink)
                            Text("\(fileCount(for: project)) Files")
                                .font(.system(size: 12))
                                .foregroundStyle(V6Color.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(V6Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous)
                            .stroke(V6Color.cardBorderInactive, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fileCount(for project: Project) -> Int {
        audioFiles.filter { $0.projectID == project.id }.count
    }

    private func color(for project: Project) -> Color {
        palette[abs(project.id.hashValue) % palette.count]
    }
}

private struct V6LifelogHighlightCard: View {
    let file: AudioFile
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(V6Color.quiet)
                Text(file.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(V6Color.ink)
                    .lineLimit(1)
                if let summary = file.summary {
                    Text(summary)
                        .font(.system(size: 12))
                        .lineSpacing(4)
                        .foregroundStyle(V6Color.muted)
                        .lineLimit(2)
                }
            }
            .frame(width: 168, alignment: .leading)
            .padding(12)
            .background(V6Color.faint, in: RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct V6LifelogMomentRow: View {
    let file: AudioFile
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                Text(file.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(V6Color.quiet)
                    .frame(width: 38, alignment: .leading)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.title)
                        .font(V6Font.rowTitle)
                        .foregroundStyle(V6Color.ink)
                    if let summary = file.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 12.5))
                            .lineSpacing(5)
                            .foregroundStyle(V6Color.muted)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(V6Color.faint).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct V6HomeFilterSheet: View {
    @Binding var selection: V6HomeFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 6) {
            row(title: "全ファイル", filter: .files)
            row(title: "プロジェクト", filter: .projects)
            row(title: "ライフログ", filter: .lifelog)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func row(title: String, filter: V6HomeFilter) -> some View {
        Button {
            selection = filter
            dismiss()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(V6Color.ink)
                Spacer()
                if selection == filter {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(V6Color.ink)
                }
            }
            .padding(14)
            .background(V6Color.faint, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct V6FileMoreSheet: View {
    let onRename: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            row(title: "タイトルを変更", color: V6Color.ink, action: onRename)
            row(title: "プロジェクトに移動", color: V6Color.ink, action: onMove)
            row(title: "削除", color: V6Color.danger, action: onDelete)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func row(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(V6Color.faint, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct V6DeleteConfirmOverlay: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("このファイルを削除しますか？")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(V6Color.ink)
                    Text("録音・文字起こし・メモはすべて削除されます。")
                        .font(.system(size: 12.5))
                        .lineSpacing(4)
                        .foregroundStyle(V6Color.muted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    Button("キャンセル", action: onCancel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(V6Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(V6Color.fillStrong, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))

                    Button("削除", action: onConfirm)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(V6Color.accent, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
                }
            }
            .padding(20)
            .background(V6Color.white, in: RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous))
            .padding(.horizontal, 40)
        }
    }
}

private struct V6PlainScreen<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(V6Font.title)
                .tracking(-0.64)
                .foregroundStyle(V6Color.ink)
                .padding(.horizontal, 18)
                .padding(.top, 30)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                content
                    .padding(.horizontal, 18)
                    .padding(.bottom, 112)
            }
        }
    }
}

private struct V6SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(V6Font.section)
            .foregroundStyle(V6Color.quiet)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }
}

private struct V6TaskRow: View {
    let title: String
    let source: String
    let done: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(done ? V6Color.ink : .clear)
                .overlay(Circle().stroke(done ? V6Color.ink : Color(hex: "C7C7CC"), lineWidth: 1.5))
                .frame(width: 17, height: 17)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(V6Font.rowTitle)
                    .foregroundStyle(done ? V6Color.muted : V6Color.ink)
                Text(source)
                    .font(.system(size: 12))
                    .foregroundStyle(V6Color.quiet)
            }
            Spacer()
        }
        .padding(.vertical, 14)
    }
}

private struct V6CitationChip: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(V6Color.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(V6Color.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct V6SettingsRow: View {
    let title: String
    let value: String
    let leading: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: leading)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(V6Color.ink)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(V6Color.ink)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundStyle(V6Color.muted)
                        .lineLimit(1)
                }
                V6DisclosureChevron()
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Dark frosted-glass fill shared by the tab bar pill and the FAB circle.
/// Source: `.dc.html` `linear-gradient(180deg, rgba(38,38,42,.68), rgba(16,16,18,.68))`
/// + `backdrop-filter: blur(26px) saturate(200%)` + `border: 1px solid rgba(255,255,255,.14)`.
private struct V6GlassPillBackground<S: Shape>: View {
    let shape: S

    var body: some View {
        ZStack {
            shape
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            shape.fill(
                LinearGradient(
                    colors: [Color(hex: "26262A").opacity(0.68), Color(hex: "101012").opacity(0.68)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            shape.stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 16, y: 12)
    }
}

private struct V6GlassTabBar: View {
    @Binding var selectedTab: Int
    let tasksBadgeCount: Int

    private let items: [(label: String, icon: String)] = [
        ("ホーム", "house.fill"),
        ("タスク", "checkmark.circle"),
        ("Ask", "sparkles"),
        ("設定", "gearshape")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    selectedTab = index
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: items[index].icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                selectedTab == index ? .white.opacity(0.16) : .clear,
                                in: Capsule()
                            )

                        if index == 1 && tasksBadgeCount > 0 {
                            Text("\(tasksBadgeCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .frame(minWidth: 14, minHeight: 14)
                                .background(Color(hex: "FF3B30").opacity(0.62), in: Capsule())
                                .offset(x: -6, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(items[index].label)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(V6GlassPillBackground(shape: Capsule()))
    }
}

private struct V6FabButton: View {
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOpen ? "xmark" : "plus")
                .font(.system(size: isOpen ? 18 : 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(V6GlassPillBackground(shape: Circle()))
        }
        .buttonStyle(V6ScalePressButtonStyle())
        .accessibilityLabel(isOpen ? "閉じる" : "録音メニュー")
    }
}

private struct V6ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
    }
}

private struct V6FabMenu: View {
    let onRecord: () -> Void
    let onImport: () -> Void
    let onMeetingCapture: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            item(title: "録音開始", action: onRecord) {
                Circle().fill(V6Color.accent).frame(width: 10, height: 10)
            }
            item(title: "インポート", action: onImport)
            item(title: "会議キャプチャー", action: onMeetingCapture)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func item(title: String, action: @escaping () -> Void, @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(V6Color.ink)
                    .lineLimit(1)
                trailing()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(V6Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct V6PaywallSheet: View {
    @Binding var isPro: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("閉じる") { dismiss() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V6Color.quiet)
                    .buttonStyle(.plain)
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)

            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text("Memora Pro")
                        .font(V6Font.proTitle)
                        .foregroundStyle(V6Color.ink)
                    Text("すべての記録を、どこからでも")
                        .font(.system(size: 13.5))
                        .foregroundStyle(V6Color.muted)
                }

                VStack(spacing: 12) {
                    ForEach(["文字起こし 月1200分（無料: 300分）", "添付のクラウド保存・全デバイス同期", "ライフログ自動セグメント無制限", "Ask AI 無制限（無料: 1日10回）"], id: \.self) { text in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(V6Color.ink)
                                .frame(width: 18, height: 18)
                                .overlay(Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white))
                            Text(text)
                                .font(.system(size: 13.5))
                                .foregroundStyle(V6Color.ink)
                            Spacer()
                        }
                    }
                }

                V6PrimaryButton(title: "7日間無料で試す") {
                    isPro = true
                    dismiss()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)

            Spacer()
        }
        .background(V6Color.white)
    }
}
