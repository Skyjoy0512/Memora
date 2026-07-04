import SwiftUI

struct DeviceConnectionView: View {
    @Environment(OmiAdapter.self) private var omiAdapter

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if omiAdapter.isConnected {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.green)

                    Text("デバイスに接続されています")
                        .font(.title2.bold())

                    if let deviceName = omiAdapter.connectedDeviceName {
                        Text(deviceName)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let statusMessage = omiAdapter.statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("状態: \(omiAdapter.connectionState.description)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("セッション終了", role: .destructive) {
                        omiAdapter.disconnect()
                    }
                    .buttonStyle(.bordered)

                    Text(omiAdapter.sessionTerminationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let errorMessage = omiAdapter.errorMessage {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.orange)

                    Text("接続を開始できませんでした")
                        .font(.title2.bold())

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("再接続") {
                        omiAdapter.startScan()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !omiAdapter.discoveredDevices.isEmpty {
                List {
                    Section("発見したデバイス") {
                        if omiAdapter.isScanning {
                            HStack {
                                ProgressView()
                                Text("引き続き検索中...")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(omiAdapter.discoveredDevices) { device in
                            Button(action: { omiAdapter.connect(to: device) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.stableDisplayName)
                                            .foregroundStyle(.primary)

                                        Text(device.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if omiAdapter.isScanning {
                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("デバイスを検索中...")
                        .font(.title2.bold())
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.secondary)

                    Text("デバイスが見つかりませんでした")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)

                    Button("再スキャン") {
                        omiAdapter.startScan()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
        }
        .padding()
    }
}

#Preview {
    DeviceConnectionView()
        .environment(OmiAdapter())
}
