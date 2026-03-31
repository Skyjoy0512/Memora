import SwiftUI

struct DeviceConnectionView: View {
    @EnvironmentObject private var bluetoothService: BluetoothAudioService
    @State private var isBluetoothEnabled = false

    var body: some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            if bluetoothService.isConnected {
                VStack(spacing: MemoraRadius.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text("デバイスに接続されています")
                        .font(MemoraTypography.headline)

                    if let device = bluetoothService.discoveredDevices.first {
                        Text(device.name)
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // 接続状態を表示
                    Text("状態: \(bluetoothService.connectionState.description)")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Button(action: { bluetoothService.disconnect() }) {
                        Text("切断")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.accentRed)
                            .cornerRadius(MemoraRadius.md)
                    }
                    .padding()
                }
            } else if bluetoothService.isScanning {
                VStack(spacing: MemoraSpacing.xxl) {
                    ProgressView()
                        .tint(MemoraColor.textSecondary)

                    Text("デバイスを検索中...")
                        .font(MemoraTypography.headline)
                }
            } else if let disconnectReason = bluetoothService.disconnectReason {
                // 切断理由を表示
                VStack(spacing: MemoraSpacing.xxl) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.orange)

                    Text("接続が切断されました")
                        .font(MemoraTypography.headline)

                    Text(disconnectReason)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: { bluetoothService.startScanning() }) {
                        Label("再接続", systemImage: "arrow.clockwise")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.divider)
                            .cornerRadius(MemoraRadius.md)
                    }
                    .padding()
                }
            } else if !bluetoothService.discoveredDevices.isEmpty {
                VStack(spacing: MemoraSpacing.xs) {
                    Text("発見したデバイス")
                        .font(MemoraTypography.headline)

                    ForEach(bluetoothService.discoveredDevices) { device in
                        Button(action: { bluetoothService.connect(to: device) }) {
                            HStack(spacing: MemoraRadius.md) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(MemoraColor.textSecondary)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
                                    Text(device.name)
                                        .font(MemoraTypography.subheadline)
                                        .foregroundStyle(.primary)

                                    Text("RSSI: \(device.rssi) dBm")
                                        .font(MemoraTypography.caption1)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .background(MemoraColor.divider.opacity(MemoraOpacity.medium))
                        .cornerRadius(MemoraRadius.sm)
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: MemoraSpacing.xxl) {
                    Spacer()

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("デバイスが見つかりませんでした")
                        .font(MemoraTypography.headline)
                        .foregroundStyle(.secondary)

                    Button(action: { bluetoothService.startScanning() }) {
                        Label("再スキャン", systemImage: "arrow.clockwise")
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
