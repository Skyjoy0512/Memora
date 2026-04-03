import SwiftUI

struct DeviceConnectionView: View {
    @EnvironmentObject private var omiAdapter: OmiAdapter

    var body: some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            if omiAdapter.isConnected {
                VStack(spacing: MemoraRadius.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text("デバイスに接続されています")
                        .font(MemoraTypography.headline)

                    if let deviceName = omiAdapter.connectedDeviceName {
                        Text(deviceName)
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let statusMessage = omiAdapter.statusMessage {
                        Text(statusMessage)
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("状態: \(omiAdapter.connectionState.description)")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.disconnect() }) {
                        Text("セッション終了")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.accentRed)
                            .cornerRadius(MemoraRadius.md)
                    }
                    .padding()

                    Text(omiAdapter.sessionTerminationDescription)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let errorMessage = omiAdapter.errorMessage {
                VStack(spacing: MemoraSpacing.xxl) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.orange)

                    Text("接続を開始できませんでした")
                        .font(MemoraTypography.headline)

                    Text(errorMessage)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: { omiAdapter.startScan() }) {
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
            } else if !omiAdapter.discoveredDevices.isEmpty {
                VStack(spacing: MemoraSpacing.xs) {
                    Text("発見したデバイス")
                        .font(MemoraTypography.headline)

                    if omiAdapter.isScanning {
                        HStack(spacing: MemoraSpacing.xs) {
                            ProgressView()
                                .tint(MemoraColor.textSecondary)

                            Text("引き続き検索中...")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(omiAdapter.discoveredDevices) { device in
                        Button(action: { omiAdapter.connect(to: device) }) {
                            HStack(spacing: MemoraRadius.md) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(MemoraColor.textSecondary)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
                                    Text(device.stableDisplayName)
                                        .font(MemoraTypography.subheadline)
                                        .foregroundStyle(.primary)

                                    Text(device.subtitle)
                                        .font(MemoraTypography.caption1)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.sm)
                    }
                    .padding(.horizontal)
                }
            } else if omiAdapter.isScanning {
                VStack(spacing: MemoraSpacing.xxl) {
                    ProgressView()
                        .tint(MemoraColor.textSecondary)

                    Text("デバイスを検索中...")
                        .font(MemoraTypography.headline)
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

                    Button(action: { omiAdapter.startScan() }) {
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
    }
}

#Preview {
    DeviceConnectionView()
        .environmentObject(OmiAdapter())
}
