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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(BluetoothAudioService.self) private var bluetoothService
    let plaudSettings: PlaudSettings?

    // MARK: - Computed Device Data

    private var deviceName: String {
        if bluetoothService.isConnected, bluetoothService.connectedDeviceType == .plaud {
            return bluetoothService.connectedDeviceName ?? "PLAUD_NOTE_Ken"
        }
        return "PLAUD_NOTE_Ken"
    }

    private var serialNumber: String {
        if let model = bluetoothService.modelNumber, !model.isEmpty {
            return model
        }
        return "123456789"
    }

    private var firmwareVersionText: String {
        if bluetoothService.isConnected, bluetoothService.connectedDeviceType == .plaud,
           let fw = bluetoothService.firmwareVersion, !fw.isEmpty {
            return fw
        }
        return "v 0.01"
    }

    private var batteryText: String {
        if bluetoothService.isConnected, bluetoothService.connectedDeviceType == .plaud,
           let level = bluetoothService.batteryLevel {
            return "\(level)%"
        }
        return "80%"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background per spec: #ECECEC
            Color(hex: "ECECEC").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    backButtonRow
                    titleRow
                    deviceImagePlaceholder
                    batteryRow
                    pageIndicatorRow
                    infoCard
                    unpairButtonRow
                }
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Back Button

    private var backButtonRow: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .frame(width: 60, height: 60)
                    .liquidGlass(cornerRadius: 30)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Title

    private var titleRow: some View {
        HStack {
            Text("PlaudNote Pro")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(MemoraColor.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Device Image Placeholder

    private var deviceImagePlaceholder: some View {
        Image(systemName: "list.bullet.rectangle")
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
            .foregroundStyle(MemoraColor.textSecondary)
            .padding(.top, 40)
    }

    // MARK: - Battery

    private var batteryRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "battery.75")
                .font(.system(size: 20, weight: .medium))
            Text(batteryText)
                .font(.system(size: 20, weight: .bold))
        }
        .foregroundStyle(MemoraColor.textPrimary)
        .padding(.top, 16)
    }

    // MARK: - Page Indicator (3 dots)

    private var pageIndicatorRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(MemoraColor.textPrimary)
                .frame(width: 8, height: 8)
            Circle()
                .fill(Color(hex: "D9D9D9"))
                .frame(width: 8, height: 8)
            Circle()
                .fill(Color(hex: "D9D9D9"))
                .frame(width: 8, height: 8)
        }
        .padding(.top, 12)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(title: "デバイス名", value: deviceName, showSeparator: true)
            infoRow(title: "シリアル番号", value: serialNumber, showSeparator: true)
            infoRow(title: "ファームウェアバージョン", value: firmwareVersionText, showSeparator: false)
        }
        .background(MemoraColor.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 48)
        .padding(.top, 32)
    }

    private func infoRow(title: String, value: String, showSeparator: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "58585A"))

                Spacer()

                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .frame(height: 88)
            .padding(.horizontal, 20)

            if showSeparator {
                Divider()
                    .foregroundStyle(MemoraColor.divider)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Unpair Button

    private var unpairButtonRow: some View {
        Button {
            unlinkPlaud()
        } label: {
            Text("ペアリングを解除")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .background(Color(hex: "FF3030"))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 48)
        .padding(.top, 24)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Actions

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
}
