import SwiftUI

// MARK: - Transcription Settings Section

struct TranscriptionSettingsSection: View {
    @Bindable var state: SettingsState
    @AppStorage("transcriptionMode") var transcriptionMode: String = "ローカル"

    var body: some View {
        Section {
            Picker("文字起こしモード", selection: $state.transcriptionMode) {
                ForEach(TranscriptionMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .tag(mode.rawValue)

                        Text(mode.description)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .pickerStyle(.inline)

            if state.currentTranscriptionMode == .api {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API文字起こしには有料プランを使用します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentRed)

                    Text("ローカル文字起こしは無料ですが、API文字起こしはプロバイダーに応じて料金が発生します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }

            if state.currentTranscriptionMode == .local {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ローカル文字起こしは SFSpeechRecognizer を使用します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Text("インターネット接続不要・無料で利用できます。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentGreen)
                }
                .padding(.vertical, MemoraSpacing.xxxs)

                if #available(iOS 26.0, *) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { SpeechAnalyzerFeatureFlag.isEnabled },
                            set: { SpeechAnalyzerFeatureFlag.isEnabled = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iOS 26 SpeechAnalyzer（ベータ）")
                                Text("有効にすると iOS 26 ネイティブエンジンを使用します。不安定な場合があります。")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if SpeechAnalyzerFeatureFlag.isEnabled {
                            Text("SpeechAnalyzer（ベータ）有効。事前診断でデバイス対応を確認後に使用します。問題がある場合は自動的に SFSpeechRecognizer に切り替わります。")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            NavigationLink {
                STTDiagnosticsView()
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .foregroundStyle(MemoraColor.accentNothing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("STT 診断")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.primary)

                        Text("backend 状態、asset 状態、フォールバック理由を確認")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }
        } header: {
            GlassSectionHeader(title: "文字起こし設定", icon: "waveform")
        }
    }
}
