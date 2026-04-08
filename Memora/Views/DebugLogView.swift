import SwiftUI

struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logger = DebugLogger.shared

    @State private var filterText = ""
    @State private var selectedLevel: LogLevel? = nil
    @State private var showSTTOnly = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var filteredLogs: [DebugLogEntry] {
        var filtered = logger.logs

        if showSTTOnly {
            filtered = filtered.filter {
                $0.category == "STTDiagnostics" || $0.category == "MemoraSTT" || $0.category == "Pipeline"
            }
        }

        if !filterText.isEmpty {
            filtered = filtered.filter {
                $0.message.localizedCaseInsensitiveContains(filterText) ||
                $0.category.localizedCaseInsensitiveContains(filterText)
            }
        }

        if let level = selectedLevel {
            filtered = filtered.filter { $0.level == level }
        }

        return filtered.reversed()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // フィルター
                filterSection

                Divider()

                // ログ一覧
                if filteredLogs.isEmpty {
                    emptyView
                } else {
                    logList
                }
            }
            .navigationTitle("デバッグログ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("エクスポート") {
                            exportLogs()
                        }

                        Divider()

                        Button("ログをクリア", role: .destructive) {
                            logger.clearLogs()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                DebugShareSheet(items: [url])
            }
        }
    }

    private var filterSection: some View {
        VStack(spacing: MemoraSpacing.xs) {
            // テキストフィルター
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("検索", text: $filterText)
                    .textFieldStyle(.plain)

                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(MemoraSpacing.xs)
            .background(MemoraColor.divider.opacity(0.1))
            .cornerRadius(MemoraRadius.sm)

            // レベルフィルター
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MemoraSpacing.xs) {
                    FilterChip(title: "STT", isSelected: showSTTOnly) {
                        showSTTOnly.toggle()
                    }

                    FilterChip(title: "すべて", isSelected: selectedLevel == nil && !showSTTOnly) {
                        selectedLevel = nil
                    }

                    ForEach(LogLevel.allCases.reversed(), id: \.self) { level in
                        FilterChip(title: level.rawValue, isSelected: selectedLevel == level) {
                            selectedLevel = level
                        }
                    }
                }
                .padding(.horizontal, MemoraSpacing.xxs)
            }
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: MemoraRadius.md) {
            Image(systemName: "tray")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundStyle(MemoraColor.textSecondary)

            Text("ログがありません")
                .font(MemoraTypography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: MemoraSpacing.xxs) {
                ForEach(filteredLogs) { entry in
                    LogEntryView(entry: entry)
                }
            }
            .padding()
        }
    }

    private func exportLogs() {
        if let url = logger.exportLogs() {
            exportURL = url
            showExportSheet = true
        }
    }
}

struct LogEntryView: View {
    let entry: DebugLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: MemoraSpacing.xs) {
            // レベルアイコン
            Image(systemName: levelIcon)
                .foregroundStyle(levelColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
                // ヘッダー
                HStack(spacing: MemoraSpacing.xs) {
                    Text(entry.category)
                        .font(MemoraTypography.caption1)
                        .fontWeight(.semibold)

                    Text(formatTime(entry.timestamp))
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                // メッセージ
                Text(entry.message)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.primary)
            }
        }
        .padding(MemoraSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(MemoraColor.divider.opacity(0.05))
        )
    }

    private var levelIcon: String {
        switch entry.level {
        case .debug:
            return "antenna.radiowaves.left.and.right"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug:
            return MemoraColor.textSecondary
        case .info:
            return MemoraColor.accentBlue
        case .warning:
            return .orange
        case .error:
            return MemoraColor.accentRed
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MemoraTypography.caption1)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, MemoraSpacing.sm)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: MemoraRadius.md)
                        .fill(isSelected ? MemoraColor.accentBlue : MemoraColor.divider.opacity(0.1))
                )
        }
    }
}

struct DebugShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DebugLogView()
    }
}
