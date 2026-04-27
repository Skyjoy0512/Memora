import SwiftUI

struct DeviceConnectionView: View {
    @Environment(OmiAdapter.self) private var omiAdapter

    var body: some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            if omiAdapter.isConnected {
                VStack(spacing: MemoraSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(MemoraColor.accentGreen)
                        .nothingGlow(.prominent)

                    Text("デバイスに接続されています")
                        .font(MemoraTypography.phiTitle)

                    if let deviceName = omiAdapter.connectedDeviceName {
                        Text(deviceName)
                            .font(MemoraTypography.phiBody)
                            .foregroundStyle(.secondary)
                    }

                    if let statusMessage = omiAdapter.statusMessage {
                        Text(statusMessage)
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(.secondary)
                    }

                    Text("状態: \(omiAdapter.connectionState.description)")
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(.secondary)

                    PillButton(title: "セッション終了", action: { omiAdapter.disconnect() }, style: .secondary)
                        .padding(.horizontal)

                    Text(omiAdapter.sessionTerminationDescription)
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(MemoraSpacing.md)
                .glassCard(.default)
                .padding(.horizontal, MemoraSpacing.md)
            } else if let errorMessage = omiAdapter.errorMessage {
                VStack(spacing: MemoraSpacing.xxl) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(MemoraColor.accentNothing)
                        .nothingGlow(.prominent)

                    Text("接続を開始できませんでした")
                        .font(MemoraTypography.phiTitle)

                    Text(errorMessage)
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    PillButton(title: "再接続", action: { omiAdapter.startScan() }, style: .primary)
                        .padding(.horizontal)
                }
                .padding(MemoraSpacing.md)
                .glassCard(.default)
                .padding(.horizontal, MemoraSpacing.md)
            } else if !omiAdapter.discoveredDevices.isEmpty {
                VStack(spacing: MemoraSpacing.sm) {
                    GlassSectionHeader(title: "発見したデバイス", icon: "antenna.radiowaves.left.and.right")
                        .padding(.horizontal, MemoraSpacing.md)

                    if omiAdapter.isScanning {
                        HStack(spacing: MemoraSpacing.xs) {
                            ProgressView()
                                .tint(MemoraColor.accentNothing)

                            Text("引き続き検索中...")
                                .font(MemoraTypography.phiCaption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, MemoraSpacing.md)
                    }

                    ForEach(omiAdapter.discoveredDevices) { device in
                        Button(action: { omiAdapter.connect(to: device) }) {
                            HStack(spacing: MemoraSpacing.md) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(MemoraColor.accentNothing)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                                    Text(device.stableDisplayName)
                                        .font(MemoraTypography.phiBody)
                                        .foregroundStyle(.primary)

                                    Text(device.subtitle)
                                        .font(MemoraTypography.phiCaption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(MemoraSpacing.md)
                        }
                        .buttonStyle(.plain)
                        .glassCard(.default)
                        .padding(.horizontal, MemoraSpacing.md)
                    }
                }
            } else if omiAdapter.isScanning {
                VStack(spacing: MemoraSpacing.xxl) {
                    ProgressView()
                        .tint(MemoraColor.accentNothing)
                        .scaleEffect(1.2)

                    Text("デバイスを検索中...")
                        .font(MemoraTypography.phiTitle)
                }
            } else {
                VStack(spacing: MemoraSpacing.xxl) {
                    Spacer()

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("デバイスが見つかりませんでした")
                        .font(MemoraTypography.phiTitle)
                        .foregroundStyle(.secondary)

                    PillButton(title: "再スキャン", action: { omiAdapter.startScan() }, style: .primary)
                        .padding(.horizontal)

                    Spacer()
                }
            }
        }
        .padding()
        .nothingTheme(showDotMatrix: true)
    }
}

#Preview {
    DeviceConnectionView()
        .environment(OmiAdapter())
}
