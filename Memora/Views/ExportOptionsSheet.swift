import SwiftUI
import SwiftData

struct ExportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let audioFile: AudioFile
    @State private var exportType: ExportType = .all
    @State private var exportFormat: ExportFormat = .txt
    @State private var isExporting = false
    @State private var errorMessage: String?

    // Notion エクスポート
    @Query private var notionSettingsList: [NotionSettings]
    @State private var notionExportType: ExportType = .all
    @State private var isExportingToNotion = false
    @State private var notionExportMessage: String?
    @State private var openAIExportFormat: OpenAIExportFormat = .markdown
    @State private var isExportingToOpenAI = false
    @State private var openAIExportMessage: String?

    private var notionSettings: NotionSettings? {
        notionSettingsList.first
    }

    private var openAIAPIKey: String {
        KeychainService.load(key: .apiKeyOpenAI).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: MemoraSpacing.xxl) {
                Spacer()

                // エクスポート種別選択
                VStack(alignment: .leading, spacing: MemoraRadius.md) {
                    Text("エクスポート内容")
                        .font(MemoraTypography.headline)

                    Picker("", selection: $exportType) {
                        ForEach(ExportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // エクスポート形式選択
                VStack(alignment: .leading, spacing: MemoraRadius.md) {
                    Text("エクスポート形式")
                        .font(MemoraTypography.headline)

                    Picker("", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // エクスポートボタン
                if isExporting {
                    ProgressView()
                        .tint(MemoraColor.textSecondary)
                } else {
                    Button(action: export) {
                        Label("エクスポート", systemImage: "square.and.arrow.down")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(MemoraColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MemoraColor.divider)
                            .clipShape(.rect(cornerRadius: MemoraRadius.md))
                    }
                }

                // エラーメッセージ
                if let error = errorMessage {
                    Text(error)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentRed)
                        .padding()
                        .background(MemoraColor.accentRed.opacity(0.1))
                        .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                }

                // Notion エクスポート（設定済みの場合のみ表示）
                if notionSettings?.isConfigured == true {
                    Divider()
                        .padding(.vertical, MemoraSpacing.xs)

                    VStack(alignment: .leading, spacing: MemoraRadius.md) {
                        Text("Notion にエクスポート")
                            .font(MemoraTypography.headline)

                        Picker("", selection: $notionExportType) {
                            ForEach(ExportType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        if isExportingToNotion {
                            HStack {
                                ProgressView()
                                Text("Notion にエクスポート中...")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Button(action: exportToNotion) {
                                Label("Notion にエクスポート", systemImage: "n.square")
                                    .font(MemoraTypography.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(MemoraColor.accentBlue)
                                    .clipShape(.rect(cornerRadius: MemoraRadius.md))
                            }
                        }

                        if let message = notionExportMessage {
                            Text(message)
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(message.contains("成功") ? MemoraColor.accentGreen : MemoraColor.accentRed)
                                .padding()
                                .background((message.contains("成功") ? MemoraColor.accentGreen : MemoraColor.accentRed).opacity(0.1))
                                .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                        }
                    }
                }

                if !openAIAPIKey.isEmpty {
                    Divider()
                        .padding(.vertical, MemoraSpacing.xs)

                    VStack(alignment: .leading, spacing: MemoraRadius.md) {
                        Text("OpenAI にアップロード")
                            .font(MemoraTypography.headline)

                        Picker("", selection: $openAIExportFormat) {
                            ForEach(OpenAIExportFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)

                        if isExportingToOpenAI {
                            HStack {
                                ProgressView()
                                Text("OpenAI にアップロード中...")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Button(action: exportToOpenAI) {
                                Label("OpenAI Files にアップロード", systemImage: "arrow.up.doc")
                                    .font(MemoraTypography.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(MemoraColor.accentGreen)
                                    .clipShape(.rect(cornerRadius: MemoraRadius.md))
                            }
                        }

                        if let message = openAIExportMessage {
                            let isSuccess = message.contains("成功")
                            Text(message)
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(isSuccess ? MemoraColor.accentGreen : MemoraColor.accentRed)
                                .padding()
                                .background((isSuccess ? MemoraColor.accentGreen : MemoraColor.accentRed).opacity(0.1))
                                .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("エクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .alert("エラー", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func export() {
        isExporting = true
        errorMessage = nil

        Task {
            do {
                let exportService = ExportService()
                let url: URL

                let transcript = fetchTranscript()
                let memoText = fetchMemoText()
                let todoItems = fetchProjectTodos()

                // エクスポート実行
                switch exportType {
                case .transcript:
                    guard let t = transcript else {
                        await MainActor.run {
                            errorMessage = "文字起こしデータがありません"
                            isExporting = false
                        }
                        return
                    }
                    url = try exportService.exportTranscript(
                        transcript: t,
                        format: exportFormat,
                        audioFile: audioFile
                    )

                case .summary:
                    url = try exportService.exportSummary(
                        audioFile: audioFile,
                        format: exportFormat
                    )

                case .all:
                    url = try exportService.exportAll(
                        transcript: transcript,
                        audioFile: audioFile,
                        format: exportFormat,
                        memoText: memoText,
                        todoItems: todoItems
                    )
                }

                // 共有シートを表示（UIActivityViewController は UIKit のため
                // activeWindowScene 経由で rootViewController を取得）
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [url],
                        applicationActivities: nil
                    )
                    if let rootViewController = UIApplication.shared.activeWindowScene?.windows.first?.rootViewController {
                        rootViewController.present(activityVC, animated: true)
                    }
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "エクスポートエラー: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }

    // MARK: - Notion Export

    private func exportToNotion() {
        guard let settings = notionSettings,
              settings.isConfigured else {
            notionExportMessage = "Notion 連携が設定されていません"
            return
        }

        isExportingToNotion = true
        notionExportMessage = nil

        Task {
            do {
                let service = NotionService()
                let token = settings.integrationToken
                let parentPageID = settings.parentPageID

                // Transcript テキストを取得
                let transcriptText = fetchTranscriptText()

                // Todo を取得（同じプロジェクトに紐づくもの）
                let todoItems = fetchProjectTodos()

                let _: NotionService.NotionPage

                switch notionExportType {
                case .all:
                    _ = try await service.createPageFromAudioFile(
                        audioFile: audioFile,
                        transcriptText: transcriptText,
                        todoItems: todoItems,
                        modelContext: modelContext,
                        token: token,
                        parentPageID: parentPageID
                    )
                case .summary:
                    _ = try await service.exportSummary(
                        audioFile: audioFile,
                        token: token,
                        parentPageID: parentPageID
                    )
                case .transcript:
                    guard let text = transcriptText else {
                        await MainActor.run {
                            notionExportMessage = "文字起こしデータがありません"
                            isExportingToNotion = false
                        }
                        return
                    }
                    _ = try await service.exportTranscript(
                        transcriptText: text,
                        audioFile: audioFile,
                        token: token,
                        parentPageID: parentPageID
                    )
                }

                // 成功
                settings.lastExportAt = Date()
                settings.updatedAt = Date()
                try? modelContext.save()

                await MainActor.run {
                    notionExportMessage = "Notion へのエクスポートに成功しました"
                    isExportingToNotion = false
                }
            } catch {
                await MainActor.run {
                    notionExportMessage = "エラー: \(error.localizedDescription)"
                    isExportingToNotion = false
                }
            }
        }
    }

    private func exportToOpenAI() {
        let apiKey = openAIAPIKey
        guard !apiKey.isEmpty else {
            openAIExportMessage = OpenAIExportError.apiKeyMissing.localizedDescription
            return
        }

        isExportingToOpenAI = true
        openAIExportMessage = nil

        Task {
            do {
                let service = OpenAIExportService(apiKey: apiKey)
                let result = try await service.exportMeeting(
                    audioFile: audioFile,
                    transcript: fetchTranscript(),
                    format: openAIExportFormat,
                    purpose: .userData,
                    memoText: fetchMemoText(),
                    todoItems: fetchProjectTodos()
                )

                await MainActor.run {
                    openAIExportMessage = "OpenAI へのアップロードに成功しました: \(result.fileId)"
                    isExportingToOpenAI = false
                }
            } catch {
                await MainActor.run {
                    openAIExportMessage = "エラー: \(error.localizedDescription)"
                    isExportingToOpenAI = false
                }
            }
        }
    }

    private func fetchTranscript() -> Transcript? {
        guard audioFile.isTranscribed else { return nil }
        let descriptor = FetchDescriptor<Transcript>()
        let transcripts = try? modelContext.fetch(descriptor)
        return transcripts?.first(where: { $0.audioFileID == audioFile.id })
    }

    private func fetchTranscriptText() -> String? {
        if let transcript = fetchTranscript() {
            return transcript.text
        }
        return audioFile.referenceTranscript
    }

    private func fetchMemoText() -> String? {
        let targetID = audioFile.id
        var descriptor = FetchDescriptor<MeetingMemo>(
            predicate: #Predicate { $0.audioFileID == targetID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.markdown
    }

    private func fetchProjectTodos() -> [TodoItem] {
        guard let projectID = audioFile.projectID else { return [] }
        let targetID = projectID
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.projectID == targetID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

private extension OpenAIExportFormat {
    var displayName: String {
        switch self {
        case .json:
            return "JSON"
        case .markdown:
            return "Markdown"
        }
    }
}
