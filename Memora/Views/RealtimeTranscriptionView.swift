import SwiftUI

struct RealtimeTranscriptionView: View {
    @EnvironmentObject private var bluetoothService: BluetoothAudioService
    @State private var isRecording = false
    @State private var isBluetoothEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            // デバイス接続状態
            if isBluetoothEnabled {
                VStack(spacing: MemoraRadius.md) {
                    Text("Omiデバイスが接続されています")
                        .font(MemoraTypography.headline)
                        .foregroundStyle(MemoraColor.accentGreen)

                    if isRecording {
                        HStack(spacing: MemoraSpacing.xxs) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)

                            Text("録音中")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentRed)
                        }
                    }
                }
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

                    Button(action: { bluetoothService.startScanning() }) {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    isRecording.toggle()
                }) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(isRecording ? MemoraColor.accentRed : MemoraColor.textSecondary)
                }
            }
        }
        .onAppear {
            isBluetoothEnabled = bluetoothService.isConnected
            // 初回表示時はスキャンを開始
            if !isBluetoothEnabled {
                bluetoothService.startScanning()
            }
        }
    }
}

#Preview {
    RealtimeTranscriptionView()
        .environmentObject(BluetoothAudioService())
}
