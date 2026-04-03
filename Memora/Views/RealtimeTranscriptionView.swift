import SwiftUI

struct RealtimeTranscriptionView: View {
    @EnvironmentObject private var omiAdapter: OmiAdapter

    var body: some View {
        VStack(spacing: 0) {
            if omiAdapter.isConnected {
                VStack(spacing: MemoraRadius.md) {
                    Text("Omi デバイスが接続されています")
                        .font(MemoraTypography.headline)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text("状態: \(omiAdapter.connectionState.description)")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    if !omiAdapter.previewTranscript.isEmpty {
                        ScrollView {
                            Text(omiAdapter.previewTranscript)
                                .font(MemoraTypography.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 220)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.md)
                    } else {
                        Text("live transcript は preview 用です。final transcript は取り込んだ音声を Memora の STT pipeline で確定します。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let importedAudio = omiAdapter.lastImportedAudio {
                        Text("最新取り込み: \(importedAudio.title)")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else {
                VStack(spacing: MemoraSpacing.xxl) {
                    Spacer()

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("Omiデバイスに接続していません")
                        .font(MemoraTypography.headline)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.startScan() }) {
                        Label("デバイスを検索", systemImage: "magnifyingglass")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.divider)
                            .cornerRadius(MemoraRadius.md)
                    }
                    .padding()

                    Spacer()
                }
            }
        }
        .navigationTitle("リアルタイム転写")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !omiAdapter.isConnected && omiAdapter.discoveredDevices.isEmpty {
                omiAdapter.startScan()
            }
        }
    }
}

#Preview {
    RealtimeTranscriptionView()
        .environmentObject(OmiAdapter())
}
