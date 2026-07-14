import SwiftUI
import UniformTypeIdentifiers

struct DeviceConnectionView: View {
    @Environment(CaptureSourceRegistry.self) private var captureRegistry
    @State private var isImportingFile = false
    @State private var importErrorMessage: String?

    private var omiAdapter: OmiAdapter? {
        captureRegistry.omiAdapter
    }

    var body: some View {
        VStack(spacing: 16) {
            discoveryToolbar

            if let omiAdapter, omiAdapter.isConnected {
                connectedState(omiAdapter)
            } else if let errorMessage = omiAdapter?.errorMessage ?? importErrorMessage {
                errorState(errorMessage)
            } else if !captureRegistry.allDevices.isEmpty {
                deviceList
            } else if omiAdapter?.isScanning == true {
                scanningState
            } else {
                emptyState
            }

            fileImportButton
        }
        .padding()
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
    }

    private var discoveryToolbar: some View {
        HStack {
            Button {
                Task { await captureRegistry.startAllDiscovery() }
            } label: {
                Label("デバイスを探す", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    private func connectedState(_ omiAdapter: OmiAdapter) -> some View {
        VStack(spacing: 16) {
            Spacer()

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

            Spacer()
        }
    }

    private func errorState(_ errorMessage: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundStyle(.orange)

            Text("接続または取込に失敗しました")
                .font(.title2.bold())

            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("再試行") {
                importErrorMessage = nil
                Task { await captureRegistry.startAllDiscovery() }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    private var deviceList: some View {
        List {
            Section("発見したデバイス") {
                if omiAdapter?.isScanning == true {
                    HStack {
                        ProgressView()
                        Text("引き続き検索中...")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(captureRegistry.allDevices) { device in
                    Button {
                        connect(to: device)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconName(for: device))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.displayName)
                                    .foregroundStyle(.primary)

                                HStack(spacing: 8) {
                                    Text(tierLabel(for: device.tier))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.secondary.opacity(0.12), in: Capsule())

                                    if let batteryLevel = device.batteryLevel {
                                        Label("\(batteryLevel)%", systemImage: "battery.75")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Text("接続")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var scanningState: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("デバイスを検索中...")
                .font(.title2.bold())
            Spacer()
        }
    }

    private var emptyState: some View {
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
                Task { await captureRegistry.startAllDiscovery() }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    private var fileImportButton: some View {
        Button {
            isImportingFile = true
        } label: {
            Label("ファイルから取り込む", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func connect(to device: CaptureDevice) {
        guard let source = captureRegistry.source(for: device.sourceType) else { return }
        Task {
            do {
                try await source.connect(to: device)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        Task { @MainActor in
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                guard let genericFileSource = captureRegistry.genericFileSource else {
                    throw CaptureError.importSinkNotConfigured
                }
                _ = try await genericFileSource.importFile(at: url)
                importErrorMessage = nil
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func tierLabel(for tier: ConnectionTier) -> String {
        switch tier {
        case .bleDirect: return "BLE 直結"
        case .cloudSync: return "クラウド"
        case .fileImport: return "ファイル"
        }
    }

    private func iconName(for device: CaptureDevice) -> String {
        switch device.tier {
        case .bleDirect: return "antenna.radiowaves.left.and.right"
        case .cloudSync: return "cloud"
        case .fileImport: return "externaldrive"
        }
    }
}

#Preview {
    DeviceConnectionView()
        .environment(CaptureSourceRegistry.preview)
}
