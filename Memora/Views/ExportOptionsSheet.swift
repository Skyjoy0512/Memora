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
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MemoraColor.divider)
                            .cornerRadius(MemoraRadius.md)
                    }
                }

                // エラーメッセージ
                if let error = errorMessage {
                    Text(error)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentRed)
                        .padding()
                        .background(MemoraColor.accentRed.opacity(MemoraOpacity.medium))
                        .cornerRadius(MemoraRadius.sm)
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

                // Transcript を取得
                let transcript: Transcript?
                if audioFile.isTranscribed {
                    let descriptor = FetchDescriptor<Transcript>()
                    let transcripts = try? modelContext.fetch(descriptor)
                    transcript = transcripts?.first(where: { $0.audioFileID == audioFile.id })
                } else {
                    transcript = nil
                }

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
                        format: exportFormat
                    )
                }

                // 共有シートを表示
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [url],
                        applicationActivities: nil
                    )
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = scene.windows.first?.rootViewController {
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
}
