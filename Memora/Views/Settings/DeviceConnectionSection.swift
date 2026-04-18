import SwiftUI
import SwiftData

// MARK: - Device Connection Section (Omi)

struct DeviceConnectionSection: View {
    @Environment(OmiAdapter.self) private var omiAdapter
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryFact.key) private var memoryFacts: [MemoryFact]
    @Query(sort: \MemoryProfile.createdAt, order: .forward) private var memoryProfiles: [MemoryProfile]
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = MemoryPrivacyMode.standard.rawValue

    var body: some View {
        Section {
            if !omiAdapter.sdkAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Omi Swift SDK が未設定です")
                        .font(MemoraTypography.subheadline)

                    Text("公式 SDK を package として追加した状態でビルドすると、scan / connect / live preview / audio import が有効になります。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            } else if omiAdapter.isConnected {
                VStack(spacing: 13) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text("デバイスに接続されています")
                        .font(MemoraTypography.subheadline)

                    if let deviceName = omiAdapter.connectedDeviceName {
                        Text(deviceName)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    if let statusMessage = omiAdapter.statusMessage {
                        Text(statusMessage)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    Text("状態: \(omiAdapter.connectionState.description)")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.disconnect() }) {
                        Text("セッション終了")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.accentRed)
                            .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                    }

                    Text(omiAdapter.sessionTerminationDescription)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            } else if !omiAdapter.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("発見したデバイス")
                            .font(MemoraTypography.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        if omiAdapter.isScanning {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)

                                Text("検索中")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(omiAdapter.discoveredDevices) { device in
                        Button(action: { omiAdapter.connect(to: device) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(MemoraColor.textSecondary)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
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
                            .padding(8)
                        }
                        .background(MemoraColor.divider.opacity(0.1))
                        .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                    }
                }
            } else if omiAdapter.isScanning {
                HStack(spacing: 13) {
                    ProgressView()
                        .tint(.gray)
                    Text("デバイスを検索中...")
                        .font(MemoraTypography.subheadline)
                }
            } else {
                VStack(spacing: 13) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("デバイスが見つかりませんでした")
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.startScan() }) {
                        Label("再スキャン", systemImage: "arrow.clockwise")
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
            GlassSectionHeader(title: "Omi 接続", icon: "headphones")
        }
    }
}
