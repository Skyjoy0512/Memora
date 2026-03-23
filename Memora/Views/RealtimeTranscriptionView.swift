import SwiftUI

struct RealtimeTranscriptionView: View {
    @EnvironmentObject private var bluetoothService: BluetoothAudioService
    @State private var isRecording = false
    @State private var isBluetoothEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            // デバイス接続状態
            if isBluetoothEnabled {
                VStack(spacing: 13) {
                    Text("Omiデバイスが接続されています")
                        .font(.headline)
                        .foregroundStyle(.green)

                    if isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)

                            Text("録音中")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } else {
                VStack(spacing: 21) {
                    Spacer()

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.gray)

                    Text("Omiデバイスに接続していません")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Button(action: { bluetoothService.startScanning() }) {
                        Label("デバイスを検索", systemImage: "magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray)
                            .cornerRadius(13)
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
                        .foregroundStyle(isRecording ? .red : .gray)
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
