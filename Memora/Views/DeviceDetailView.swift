import SwiftUI
import SwiftData

struct DeviceStatusToolbarButton: View {
    let omiState: OmiConnectionState
    let isOmiConnected: Bool
    let isPlaudConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            statusChip(title: "Omi", isConnected: isOmiConnected, isActive: omiState == .scanning || omiState == .connecting)
            statusChip(title: "Plaud", isConnected: isPlaudConnected, isActive: false)
        }
        .padding(.horizontal, 2)
    }

    private func statusChip(title: String, isConnected: Bool, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? MemoraColor.accentGreen : (isActive ? MemoraColor.accentNothing : MemoraColor.textTertiary))
                .frame(width: 6, height: 6)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MemoraColor.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(MemoraColor.interactiveSecondaryBorder.opacity(0.7), lineWidth: 0.5)
        }
    }
}

struct DeviceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(OmiAdapter.self) private var omiAdapter
    @Environment(BluetoothAudioService.self) private var bluetoothService
    let plaudSettings: PlaudSettings?
    @State private var firmwareNotice: String?

    var body: some View {
        List {
            omiSection
            plaudSection
            bluetoothSection
        }
        .navigationTitle("デバイス")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .alert("ファームウェアアップデート", isPresented: Binding(
            get: { firmwareNotice != nil },
            set: { if !$0 { firmwareNotice = nil } }
        )) {
            Button("OK", role: .cancel) { firmwareNotice = nil }
        } message: {
            if let firmwareNotice {
                Text(firmwareNotice)
            }
        }
    }

    private var omiSection: some View {
        Section {
            deviceHeader(
                title: "Omi",
                subtitle: omiAdapter.connectedDeviceName ?? omiAdapter.connectionState.description,
                icon: "headphones",
                isConnected: omiAdapter.isConnected,
                stateText: omiAdapter.connectionState.description
            )

            detailRow(title: "バッテリー", value: "未取得", icon: "battery.50")
            detailRow(title: "ファームウェア", value: "SDK未対応", icon: "shippingbox")

            Button {
                firmwareNotice = "現在の Omi SDK からはファームウェア更新APIが公開されていないため、アプリ内更新は未対応です。SDK側で提供されたらここに接続します。"
            } label: {
                Label("アップデートを確認", systemImage: "arrow.down.circle")
            }

            if let statusMessage = omiAdapter.statusMessage {
                detailRow(title: "状態メモ", value: statusMessage, icon: "info.circle")
            }

            if omiAdapter.isConnected {
                Button(role: .destructive) {
                    omiAdapter.disconnect()
                } label: {
                    Label("Omi セッションを終了", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    omiAdapter.startScan()
                } label: {
                    Label(omiAdapter.isScanning ? "検索中..." : "Omi を検索", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(omiAdapter.isScanning)
            }
        } header: {
            Text("Omi")
        } footer: {
            Text(omiAdapter.sessionTerminationDescription)
        }
    }

    private var plaudSection: some View {
        Section {
            let isLinked = plaudSettings?.isEnabled == true && plaudSettings?.isTokenValid == true
            deviceHeader(
                title: "Plaud",
                subtitle: plaudSubtitle,
                icon: "waveform",
                isConnected: isLinked || (bluetoothService.isConnected && bluetoothService.connectedDeviceType == .plaud),
                stateText: isLinked ? "クラウド連携中" : "未連携"
            )

            detailRow(title: "バッテリー", value: plaudBatteryText, icon: "battery.50")
            detailRow(title: "ファームウェア", value: bluetoothService.connectedDeviceType == .plaud ? (bluetoothService.firmwareVersion ?? "未取得") : "未取得", icon: "shippingbox")

            Button {
                firmwareNotice = "Plaud のファームウェア更新は公式アプリ側の管理です。Memora では連携状態とBLEで取得できる端末情報のみ表示します。"
            } label: {
                Label("アップデートを確認", systemImage: "arrow.down.circle")
            }

            if let lastSyncAt = plaudSettings?.lastSyncAt {
                detailRow(title: "最終同期", value: lastSyncAt.formatted(date: .abbreviated, time: .shortened), icon: "clock")
            }

            if plaudSettings != nil {
                Button(role: .destructive) {
                    unlinkPlaud()
                } label: {
                    Label("Plaud 連携を解除", systemImage: "link.badge.minus")
                }
            }
        } header: {
            Text("Plaud")
        } footer: {
            Text("Plaud のバッテリー/ファームウェアはBLEで接続できた場合のみ表示します。クラウド連携だけの場合は同期状態を表示します。")
        }
    }

    private var bluetoothSection: some View {
        Section {
            if bluetoothService.isConnected {
                deviceHeader(
                    title: bluetoothService.connectedDeviceType.displayName,
                    subtitle: bluetoothService.connectedDeviceName ?? "接続中",
                    icon: bluetoothService.connectedDeviceType.iconName,
                    isConnected: true,
                    stateText: bluetoothService.connectionState.description
                )
                detailRow(title: "バッテリー", value: bluetoothService.batteryLevel.map { "\($0)%" } ?? "未取得", icon: "battery.50")
                detailRow(title: "モデル", value: bluetoothService.modelNumber ?? "未取得", icon: "tag")
                detailRow(title: "ファームウェア", value: bluetoothService.firmwareVersion ?? "未取得", icon: "shippingbox")

                Button {
                    firmwareNotice = "接続中のBLEデバイスに対するファームウェア更新手順が未定義です。更新用characteristic/APIが分かればここから実行できます。"
                } label: {
                    Label("アップデートを確認", systemImage: "arrow.down.circle")
                }

                Button(role: .destructive) {
                    bluetoothService.disconnect()
                } label: {
                    Label("BLE デバイスを解除", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    bluetoothService.startScanning()
                } label: {
                    Label(bluetoothService.isScanning ? "検索中..." : "BLE デバイスを検索", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(bluetoothService.isScanning)
            }
        } header: {
            Text("BLE 詳細")
        }
    }

    private var plaudSubtitle: String {
        if bluetoothService.isConnected && bluetoothService.connectedDeviceType == .plaud {
            return bluetoothService.connectedDeviceName ?? "BLE 接続中"
        }
        guard let plaudSettings else { return "未設定" }
        return plaudSettings.email.isEmpty ? plaudSettings.apiServer : plaudSettings.email
    }

    private var plaudBatteryText: String {
        guard bluetoothService.isConnected, bluetoothService.connectedDeviceType == .plaud else {
            return "未取得"
        }
        return bluetoothService.batteryLevel.map { "\($0)%" } ?? "未取得"
    }

    private func unlinkPlaud() {
        guard let plaudSettings else { return }
        plaudSettings.isEnabled = false
        plaudSettings.autoSyncEnabled = false
        plaudSettings.updatedAt = Date()
        KeychainService.delete(key: .plaudAccessToken)
        KeychainService.delete(key: .plaudRefreshToken)
        KeychainService.delete(key: .plaudTokenExpiresAt)
        try? modelContext.save()
    }

    private func deviceHeader(title: String, subtitle: String, icon: String, isConnected: Bool, stateText: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isConnected ? MemoraColor.accentGreen : MemoraColor.textTertiary)
                .frame(width: 40, height: 40)
                .background(MemoraColor.divider.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MemoraTypography.subheadline)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(subtitle)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            Spacer()

            Text(stateText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isConnected ? MemoraColor.accentGreen : MemoraColor.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((isConnected ? MemoraColor.accentGreen : MemoraColor.divider).opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 4)
    }

    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(MemoraColor.textTertiary)
                .frame(width: 22)

            Text(title)
                .foregroundStyle(MemoraColor.textPrimary)

            Spacer()

            Text(value)
                .foregroundStyle(MemoraColor.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .font(MemoraTypography.subheadline)
    }
}
