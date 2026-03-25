import SwiftUI

struct DeviceConnectionView: View {
    @EnvironmentObject private var bluetoothService: BluetoothAudioService
    @State private var isBluetoothEnabled = false

    var body: some View {
        VStack(spacing: 21) {
            Spacer()

            if bluetoothService.isConnected {
                VStack(spacing: 13) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.green)

                    Text("デバイスに接続されています")
                        .font(.headline)

                    if let device = bluetoothService.discoveredDevices.first {
                        Text(device.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // 接続状態を表示
                    Text("状態: \(bluetoothService.connectionState.description)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: { bluetoothService.disconnect() }) {
                        Text("切断")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(13)
                    }
                    .padding()
                }
            } else if bluetoothService.isScanning {
                VStack(spacing: 21) {
                    ProgressView()
                        .tint(.gray)

                    Text("デバイスを検索中...")
                        .font(.headline)
                }
            } else if let disconnectReason = bluetoothService.disconnectReason {
                // 切断理由を表示
                VStack(spacing: 21) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.orange)

                    Text("接続が切断されました")
                        .font(.headline)

                    Text(disconnectReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: { bluetoothService.startScanning() }) {
                        Label("再接続", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray)
                            .cornerRadius(13)
                    }
                    .padding()
                }
            } else if !bluetoothService.discoveredDevices.isEmpty {
                VStack(spacing: 8) {
                    Text("発見したデバイス")
                        .font(.headline)

                    ForEach(bluetoothService.discoveredDevices) { device in
                        Button(action: { bluetoothService.connect(to: device) }) {
                            HStack(spacing: 13) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(.gray)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    Text("RSSI: \(device.rssi) dBm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 21) {
                    Spacer()

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.gray)

                    Text("デバイスが見つかりませんでした")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Button(action: { bluetoothService.startScanning() }) {
                        Label("再スキャン", systemImage: "arrow.clockwise")
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
        .padding()
        .onChange(of: bluetoothService.isConnected) { newValue in
            isBluetoothEnabled = newValue
        }
        .onChange(of: bluetoothService.isScanning) { newValue in
            // スキャン状態の変化でbluetooth接続状態も更新
            isBluetoothEnabled = bluetoothService.isConnected
        }
        .onAppear {
            isBluetoothEnabled = bluetoothService.isConnected
        }
    }
}

#Preview {
    DeviceConnectionView()
        .environmentObject(BluetoothAudioService())
}
