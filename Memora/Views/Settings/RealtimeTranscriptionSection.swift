import SwiftUI

// MARK: - Omi Preview (Realtime Transcription) Section

struct RealtimeTranscriptionSection: View {
    @Environment(OmiAdapter.self) private var omiAdapter

    var body: some View {
        Section {
            if omiAdapter.isConnected {
                VStack(spacing: 13) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentGreen)
                        Text("公式 Omi path で接続中")
                            .font(MemoraTypography.subheadline)
                    }

                    Text("live transcript は preview 用です。取り込んだ audio file を Memora 側 STT pipeline で再処理して final transcript を確定します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    if !omiAdapter.previewTranscript.isEmpty {
                        ScrollView {
                            Text(omiAdapter.previewTranscript)
                                .font(MemoraTypography.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 80, maxHeight: 180)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(MemoraColor.divider.opacity(0.1))
                        .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                    }

                    if let importedAudio = omiAdapter.lastImportedAudio {
                        Text("取り込み済み: \(importedAudio.title)")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 13) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("デバイスに接続していません")
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.startScan() }) {
                        Label("デバイスを検索", systemImage: "magnifyingglass")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(MemoraColor.textPrimary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.divider)
                            .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                    }
                }
            }
        } header: {
            GlassSectionHeader(title: "Omi Preview", icon: "mic.fill")
        }
    }
}
