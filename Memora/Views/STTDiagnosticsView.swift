import SwiftUI

struct STTDiagnosticsView: View {
    @AppStorage("selectedProvider") private var selectedProvider: String = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @AppStorage("speechAnalyzerEnabled") private var speechAnalyzerEnabled: Bool = false
    @AppStorage("sttDiagnosticsLastFallbackReason") private var storedFallbackReason = "未診断"

    @State private var snapshot: STTDiagnosticsSnapshot?
    @State private var recentEntries: [STTBackendDiagnosticEntry] = []
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    private var currentMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    private var currentAPIKey: String {
        switch currentProvider {
        case .openai:
            return KeychainService.load(key: .apiKeyOpenAI)
        case .gemini:
            return KeychainService.load(key: .apiKeyGemini)
        case .deepseek:
            return KeychainService.load(key: .apiKeyDeepSeek)
        case .local:
            return ""
        }
    }

    private var lastRecordedEntry: STTBackendDiagnosticEntry? {
        recentEntries.last ?? STTDiagnosticsLog.shared.persistedLastEntry
    }

    private var lastFallbackReasonText: String {
        let normalizedStoredReason = storedFallbackReason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedStoredReason.isEmpty, normalizedStoredReason != "未診断" {
            return normalizedStoredReason
        }

        if let runtimeReason = lastRecordedEntry?.fallbackReason, !runtimeReason.isEmpty {
            return runtimeReason
        }

        return "まだフォールバックは記録されていません。"
    }

    var body: some View {
        List {
            configurationSection
            diagnosticsSection
            recoverySection
            recentExecutionSection
            fallbackSection
            testSection
        }
        .navigationTitle("STT 診断")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard snapshot == nil else { return }
            await refreshDiagnostics(performFullTest: false)
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        Section("現在の構成") {
            LabeledContent("文字起こしモード", value: currentMode.rawValue)
            LabeledContent("AI プロバイダー", value: currentProvider.rawValue)

            if currentMode == .local {
                LabeledContent("SpeechAnalyzer", value: speechAnalyzerEnabled ? "ON" : "OFF")
            } else {
                LabeledContent("API キー", value: currentAPIKey.isEmpty ? "未設定" : "設定済み")
            }
        }
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section("診断パネル") {
            if let snapshot {
                STTDiagnosticsCard(snapshot.backendPanel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                STTDiagnosticsCard(snapshot.assetPanel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                    Text("診断メモ")
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    Text(snapshot.testSummary)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Text("診断モード: \(snapshot.diagnosticModeLabel)")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("Fallback chain: SpeechAnalyzer → SFSpeechRecognizer → API")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("更新: \(snapshot.generatedAtText)")
                        .font(MemoraTypography.caption2)
                        .foregroundStyle(MemoraColor.textTertiary)
                }
                .padding(MemoraSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MemoraColor.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
            } else if isRefreshing {
                HStack(spacing: MemoraSpacing.sm) {
                    ProgressView()
                    Text("診断情報を取得中...")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentRed)
            } else {
                Text("診断情報はまだありません。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var recoverySection: some View {
        if let category = snapshot?.lastFailureCategory {
            Section("復旧ヒント") {
                VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                    HStack(spacing: MemoraSpacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(category.localizedTitle)
                            .font(MemoraTypography.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text(category.recoveryAction)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding(MemoraSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { Color.yellow.opacity(0.08) }
                .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
            }
        }
    }

    @ViewBuilder
    private var recentExecutionSection: some View {
        Section("直近の実行ログ") {
            if let lastRecordedEntry {
                STTLastExecutionCard(entry: lastRecordedEntry)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if recentEntries.count > 1 {
                    VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                        Text("履歴")
                            .font(MemoraTypography.subheadline)
                            .fontWeight(.semibold)

                        ForEach(Array(recentEntries.reversed().dropFirst().prefix(4))) { entry in
                            HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                                Text(entry.recordedAtText)
                                    .font(MemoraTypography.caption2)
                                    .foregroundStyle(MemoraColor.textTertiary)
                                    .frame(width: 110, alignment: .leading)

                                Text(entry.summary)
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(MemoraSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MemoraColor.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                }
            } else {
                Text("まだ文字起こし実行ログはありません。ここには実際の backend 使用履歴を表示します。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var fallbackSection: some View {
        Section("前回のフォールバック理由") {
            Text(lastFallbackReasonText)
                .font(MemoraTypography.body)
                .foregroundStyle(.primary)

            if let snapshot {
                Text("現在の判定: \(snapshot.fallbackReason)")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }

            Text("ここには実際の文字起こし実行で記録された最後のフォールバック理由を保持します。")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var testSection: some View {
        Section("テスト文字起こし診断") {
            Button {
                Task {
                    await refreshDiagnostics(performFullTest: true)
                }
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(MemoraColor.accentBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRefreshing ? "診断を実行中..." : "テスト診断を実行")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.primary)

                        Text("backend 選択、権限、locale、asset 状態を同じ経路で再評価")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }
            .disabled(isRefreshing)

            Text("実音声の文字起こしは走らせません。ローカル + SpeechAnalyzer ON の場合は preflight を実行し、必要に応じて asset install request まで確認します。")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func refreshDiagnostics(performFullTest: Bool) async {
        isRefreshing = true
        errorMessage = nil

        let snapshot = await STTDiagnosticsRunner.makeSnapshot(
            mode: currentMode,
            provider: currentProvider,
            speechAnalyzerEnabled: speechAnalyzerEnabled,
            apiKeyConfigured: !currentAPIKey.isEmpty,
            performFullTest: performFullTest
        )

        self.snapshot = snapshot
        let inMemoryEntries = STTDiagnosticsLog.shared.recentEntries
        if inMemoryEntries.isEmpty, let persistedEntry = STTDiagnosticsLog.shared.persistedLastEntry {
            self.recentEntries = [persistedEntry]
        } else {
            self.recentEntries = inMemoryEntries
        }
        self.isRefreshing = false
    }
}

struct STTLastExecutionCard: View {
    let entry: STTBackendDiagnosticEntry

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Execution")
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    Text(entry.backend.rawValue)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.recordedAtText)
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textTertiary)
            }

            VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                labeledLine("task", value: entry.taskId)
                labeledLine("locale", value: entry.locale)
                if let assetState = entry.assetState {
                    labeledLine("asset", value: assetState)
                }
                if let audioFormat = entry.audioFormat, !audioFormat.isEmpty {
                    labeledLine("format", value: audioFormat)
                }
                if let processingTimeMs = entry.processingTimeMs {
                    labeledLine("time", value: String(format: "%.1fms", processingTimeMs))
                }
                if let fallbackReason = entry.fallbackReason, !fallbackReason.isEmpty {
                    labeledLine("fallback", value: fallbackReason)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
    }

    @ViewBuilder
    private func labeledLine(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: MemoraSpacing.xs) {
            Text("\(title):")
                .font(MemoraTypography.caption1)
                .foregroundStyle(MemoraColor.textSecondary)

            Text(value)
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }
}

extension STTBackendDiagnosticEntry {
    private static let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return f
    }()

    var recordedAtText: String {
        Self.logDateFormatter.string(from: recordedAt)
    }
}
