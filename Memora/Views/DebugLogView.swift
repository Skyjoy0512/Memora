import SwiftUI

struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logger = DebugLogger.shared

    @State private var filterText = ""
    @State private var selectedLevel: LogLevel? = nil
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var filteredLogs: [DebugLogEntry] {
        var filtered = logger.logs

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
        VStack(spacing: 8) {
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
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // レベルフィルター
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "すべて", isSelected: selectedLevel == nil) {
                        selectedLevel = nil
                    }

                    ForEach(LogLevel.allCases.reversed(), id: \.self) { level in
                        FilterChip(title: level.rawValue, isSelected: selectedLevel == level) {
                            selectedLevel = level
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 13) {
            Image(systemName: "tray")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundStyle(.gray)

            Text("ログがありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
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
        HStack(alignment: .top, spacing: 8) {
            // レベルアイコン
            Image(systemName: levelIcon)
                .foregroundStyle(levelColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                // ヘッダー
                HStack(spacing: 8) {
                    Text(entry.category)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text(formatTime(entry.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                // メッセージ
                Text(entry.message)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.05))
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
            return .gray
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
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
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
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
