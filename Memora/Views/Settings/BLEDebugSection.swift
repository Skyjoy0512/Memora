import SwiftUI
import SwiftData

// MARK: - BLE Debug Section

struct BLEDebugSection: View {
    @Environment(BluetoothAudioService.self) private var bluetoothService

    var body: some View {
        if bluetoothService.isConnected {
            Section {
                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("発見されたサービス UUID:")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)

                        ForEach(bluetoothService.discoveredServices, id: \.uuidString) { serviceUUID in
                            Text(serviceUUID.uuidString)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.vertical, MemoraSpacing.xxxs)
                        }

                        if bluetoothService.discoveredServices.isEmpty {
                            Text("サービスが見つかりません")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("発見されたキャラクタリスティック UUID:")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)

                        ForEach(bluetoothService.discoveredCharacteristics, id: \.uuidString) { characteristicUUID in
                            Text(characteristicUUID.uuidString)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.vertical, MemoraSpacing.xxxs)
                        }

                        if bluetoothService.discoveredCharacteristics.isEmpty {
                            Text("キャラクタリスティックが見つかりません")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                GlassSectionHeader(title: "汎用 BLE 実験機能（開発者向け）", icon: "antenna.radiowaves.left.and.right")
            }
        }
    }
}
