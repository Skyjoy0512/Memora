import SwiftUI
import SwiftData

// MARK: - Device Connection Section (Omi)

struct DeviceConnectionSection: View {
    @Environment(CaptureSourceRegistry.self) private var captureRegistry
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryFact.key) private var memoryFacts: [MemoryFact]
    @Query(sort: \MemoryProfile.createdAt, order: .forward) private var memoryProfiles: [MemoryProfile]
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = MemoryPrivacyMode.standard.rawValue

    private var omiAdapter: OmiAdapter? {
        captureRegistry.omiAdapter
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Omi は Bluetooth Low Energy（BLE）で直接接続します。")
                    .font(MemoraTypography.caption1)
                Text("PLAUDなどのレコーダーは、各アプリやFilesから書き出した音声・JSON・TXTファイルをホームのファイル読み込みで取り込めます。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }

            if let omiAdapter, !omiAdapter.sdkAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Omi Swift SDK が未設定です")
                        .font(MemoraTypography.subheadline)

                    Text("公式 SDK を package として追加した状態でビルドすると、scan / connect / live preview / audio import が有効になります。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            } else if let omiAdapter, omiAdapter.isConnected {
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
            } else if let omiAdapter, !omiAdapter.discoveredDevices.isEmpty {
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
            } else if omiAdapter?.isScanning == true {
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

                    Button(action: {
                        Task { await captureRegistry.startAllDiscovery() }
                    }) {
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
            GlassSectionHeader(title: "録音デバイス", icon: "headphones")
        }
    }
}
