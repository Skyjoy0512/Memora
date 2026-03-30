import Foundation
@preconcurrency import CoreBluetooth
import Combine
import AVFoundation

/// Bluetooth 音声サービス
/// Omi/Plaud デバイスから音声ストリームを受信する
final class BluetoothAudioService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var isRecording = false
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var errorMessage: String?
    @Published var discoveredServices: [CBUUID] = []
    @Published var discoveredCharacteristics: [CBUUID] = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var connectionState: ConnectionState = .disconnected
    @Published var disconnectReason: String?

    private lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: nil)
    }()
    private var connectedPeripheral: CBPeripheral?
    private var audioCharacteristic: CBCharacteristic?
    private var audioBuffer = Data()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var audioFileURL: URL?
    private var connectionRetryTimer: Timer?
    private var retryCount = 0
    private let maxRetryCount = 3

    // 接続状態
    enum ConnectionState: String, CustomStringConvertible {
        case disconnected = "切断済み"
        case scanning = "スキャン中"
        case connecting = "接続中"
        case connected = "接続済み"
        case discoveringServices = "サービス探索中"
        case discoveringCharacteristics = "キャラクタリスティック探索中"
        case ready = "準備完了"

        var description: String {
            rawValue
        }
    }

    // デバイスタイプ
    enum DeviceType {
        case omi
        case plaud
        case unknown
    }

    // Omi デバイスのサービス UUID
    private lazy var omiServiceUUIDs: [CBUUID] = [
        CBUUID(string: "00001804-0000-1000-8000-00805f9b34fb"),
        CBUUID(string: "f000ffc1-0451-4000-b000-000000000000"),
        CBUUID(string: "f000ffc1-0451-4001-b000-000000000000"),
        CBUUID(string: "00001800-0000-1000-8000-00805f9b34fb"),
        CBUUID(string: "00001801-0000-1000-8000-00805f9b34fb")
    ]

    // オーディオキャラクタリスティック UUID
    private lazy var audioCharacteristicUUIDs: [CBUUID] = [
        CBUUID(string: "f000ffc1-0451-4001-b000-000000000000"),
        CBUUID(string: "f000ffc1-0451-4000-b000-000000000000"),
        CBUUID(string: "00002a29-0000-1000-8000-00805f9b34fb"),
        CBUUID(string: "00002a24-0000-1000-8000-00805f9b34fb"),
        CBUUID(string: "00002a25-0000-1000-8000-00805f9b34fb"),
        CBUUID(string: "00002a27-0000-1000-8000-00805f9b34fb"),
        CBUUID(string: "00002a26-0000-1000-8000-00805f9b34fb"),
        CBUUID(string: "00002a28-0000-1000-8000-00805f9b34fb")
    ]

    // Plaud デバイスの UUID
    private lazy var plaudServiceUUID = CBUUID(string: "00001800-0000-1000-8000-00805f9b34fb")
    private lazy var plaudAudioServiceUUID = CBUUID(string: "00001803-0000-1000-8000-00805f9b34fb")
    private var plaudDeviceType: DeviceType = .unknown

    // MARK: - スキャン開始・停止

    func startScanning() {
        isScanning = true
        connectionState = .scanning
        errorMessage = nil
        disconnectReason = nil
        discoveredDevices.removeAll()
        discoveredServices.removeAll()
        discoveredCharacteristics.removeAll()

        // 既に接続されているデバイスがあれば切断
        if let peripheral = connectedPeripheral {
            print("既存の接続を切断します: \(peripheral.name ?? "Unknown")")
            centralManager.cancelPeripheralConnection(peripheral)
        }

        // すべてのデバイスをスキャン（サービス UUID 指定なし）
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        print("📡 スキャンを開始しました...")

        // 30秒後にスキャン停止（延長）
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        if isScanning {
            isScanning = false
            centralManager.stopScan()
            print("📡 スキャンを停止しました")
        }
    }

    // MARK: - 接続・切断

    func connect(to device: BluetoothDevice) {
        errorMessage = nil
        disconnectReason = nil
        plaudDeviceType = device.deviceType
        retryCount = 0
        connectionState = .connecting

        // 既存の再接続タイマーをキャンセル
        connectionRetryTimer?.invalidate()
        connectionRetryTimer = nil

        print("🔗 接続を試みます: \(device.name), タイプ: \(device.deviceType)")
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        stopRecording()

        // 再接続タイマーをキャンセル（意図的な切断の場合）
        connectionRetryTimer?.invalidate()
        connectionRetryTimer = nil
        retryCount = maxRetryCount + 1 // 自動再接続を無効化

        disconnectReason = "ユーザーによる切断"
        connectionState = .disconnected

        if let peripheral = connectedPeripheral {
            print("🔌 切断します: \(peripheral.name ?? "Unknown")")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // MARK: - 録音制御

    func startRecording() {
        guard isConnected && audioCharacteristic != nil else {
            errorMessage = "デバイスが接続されていません"
            return
        }

        guard !isRecording else {
            errorMessage = "既に録音中です"
            return
        }

        isRecording = true
        audioBuffer = Data()
        recordingStartTime = Date()
        recordingDuration = 0

        // 録音タイマー開始
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingDuration()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        // バッファリングしたデータを保存
        saveRecording()
    }

    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }

    private func saveRecording() {
        guard !audioBuffer.isEmpty else { return }

        // ドキュメントフォルダに保存
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "bluetooth_recording_\(timestamp).wav"
        let destinationUrl = documentsDir.appendingPathComponent(filename)

        // WAV ファイルとして保存
        let wavData = convertToWAV(audioBuffer: audioBuffer)

        do {
            try wavData.write(to: destinationUrl)
            print("録音を保存しました: \(destinationUrl.path)")
            audioFileURL = destinationUrl
        } catch {
            errorMessage = "録音の保存に失敗しました: \(error.localizedDescription)"
        }

        audioBuffer = Data()
    }

    private func convertToWAV(audioBuffer: Data) -> Data {
        // 受信したデータを WAV 形式に変換
        // 16kHz、16bit、モノラルを想定
        var sampleRate: UInt32 = 16000
        var numChannels: UInt16 = 1
        var bitsPerSample: UInt16 = 16
        var byteRate: UInt32 = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        var blockAlign: UInt16 = numChannels * UInt16(bitsPerSample / 8)

        var wav = Data()

        // RIFF ヘッダー
        wav.append("RIFF".data(using: .ascii)!)
        var fileSize: UInt32 = 36 + UInt32(audioBuffer.count)
        wav.append(Data(bytes: &fileSize, count: 4))
        wav.append("WAVE".data(using: .ascii)!)

        // fmt チャンク
        wav.append("fmt ".data(using: .ascii)!)
        var fmtSize: UInt32 = 16
        wav.append(Data(bytes: &fmtSize, count: 4))
        var audioFormat: UInt16 = 1 // PCM
        wav.append(Data(bytes: &audioFormat, count: 2))
        wav.append(Data(bytes: &numChannels, count: 2))
        wav.append(Data(bytes: &sampleRate, count: 4))
        wav.append(Data(bytes: &byteRate, count: 4))
        wav.append(Data(bytes: &blockAlign, count: 2))
        wav.append(Data(bytes: &bitsPerSample, count: 2))

        // data チャンク
        wav.append("data".data(using: .ascii)!)
        var dataSize: UInt32 = UInt32(audioBuffer.count)
        wav.append(Data(bytes: &dataSize, count: 4))

        wav.append(audioBuffer)

        return wav
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothAudioService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch central.state {
            case .poweredOn:
                print("Bluetooth: Powered On")
            case .poweredOff:
                print("Bluetooth: Powered Off")
                self.errorMessage = "Bluetoothがオフです"
            case .unauthorized:
                print("Bluetooth: Unauthorized")
                self.errorMessage = "Bluetooth の許可が必要です"
            default:
                break
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 既に見つかったデバイスはスキップ
            if self.discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                return
            }

            // デバイスタイプを識別
            let deviceName = peripheral.name ?? "Unknown Device"
            var deviceType: DeviceType = .unknown

            if deviceName.lowercased().contains("omi") {
                deviceType = .omi
            } else if deviceName.lowercased().contains("plaud") {
                deviceType = .plaud
            }

            let device = BluetoothDevice(
                identifier: peripheral.identifier,
                name: deviceName,
                peripheral: peripheral,
                rssi: RSSI.intValue,
                deviceType: deviceType
            )

            self.discoveredDevices.append(device)
            print("発見したデバイス: \(deviceName), タイプ: \(deviceType), RSSI: \(RSSI.intValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("✅ 接続しました: \(peripheral.name ?? "Unknown")")
            print("   Peripheral ID: \(peripheral.identifier)")
            print("   サービス数: \(peripheral.services?.count ?? 0)")

            self.isConnected = true
            self.connectionState = .connected
            self.isScanning = false
            self.stopScanning()
            self.errorMessage = nil
            self.disconnectReason = nil
            self.retryCount = 0

            // サービスを探索（デバイスタイプに応じて異なる UUID）
            peripheral.delegate = self

            // 接続後、少し待ってからサービスを探索（安定性向上）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.connectionState = .discoveringServices

                switch self.plaudDeviceType {
                case .omi:
                    // Omi デバイスは複数のサービス UUID を探索
                    peripheral.discoverServices(self.omiServiceUUIDs)
                case .plaud:
                    // Plaud デバイスはすべてのサービスを探索
                    peripheral.discoverServices(nil)
                case .unknown:
                    // 未知のデバイスはすべてのサービスを探索
                    peripheral.discoverServices(nil)
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("⚠️ 切断しました: \(peripheral.name ?? "Unknown")")

            if let error = error {
                let errorCode = (error as NSError).code
                let errorDomain = (error as NSError).domain
                print("   エラードメイン: \(errorDomain)")
                print("   エラーコード: \(errorCode)")
                print("   エラー詳細: \(error.localizedDescription)")

                self.disconnectReason = "エラー: \(error.localizedDescription) (コード: \(errorCode))"

                // 特定のエラーコードに基づいて適切な対処
                switch errorCode {
                case 6: // Connection timeout
                    self.disconnectReason = "接続タイムアウト"
                case 7: // Peripheral disconnected
                    self.disconnectReason = "デバイス側で切断されました"
                case 13: // Peer not connected
                    self.disconnectReason = "ピアが接続されていません"
                default:
                    self.disconnectReason = "不明な切断エラー"
                }
            } else {
                self.disconnectReason = "意図的な切断"
            }

            self.isConnected = false
            self.connectionState = .disconnected
            self.connectedPeripheral = nil
            self.audioCharacteristic = nil

            // 自動再接続を試みる（エラーがある場合のみ）
            if error != nil && self.retryCount < self.maxRetryCount {
                self.retryCount += 1
                print("🔄 再接続を試みます (\(self.retryCount)/\(self.maxRetryCount))...")

                self.connectionRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    self?.startScanning()
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("接続失敗: \(peripheral.name ?? "Unknown"), Error: \(error?.localizedDescription ?? "Unknown")")

            self.isConnected = false
            self.errorMessage = "接続失敗: \(error?.localizedDescription ?? "不明なエラー")"
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothAudioService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard error == nil else {
                print("❌ サービス探索エラー: \(error!.localizedDescription)")
                self.errorMessage = "サービス探索エラー: \(error!.localizedDescription)"
                self.connectionState = .disconnected
                return
            }

            guard let services = peripheral.services else {
                print("⚠️ サービスが見つかりませんでした")
                self.errorMessage = "サービスが見つかりませんでした"
                self.connectionState = .disconnected
                return
            }

            print("✅ 発見されたサービス数: \(services.count)")
            var discoveredUUIDs: [CBUUID] = []
            for service in services {
                let uuidString = service.uuid.uuidString
                print("  サービス UUID: \(uuidString)")
                discoveredUUIDs.append(service.uuid)

                // Nordic UART サービスが見つかった場合
                if uuidString.hasPrefix("F000FFC1") {
                    print("    → Nordic UART Service と特定しました")
                }
            }

            // 発見されたサービスを保存（UI に表示可能）
            self.discoveredServices = discoveredUUIDs

            // 次にキャラクタリスティックを探索
            self.connectionState = .discoveringCharacteristics

            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard error == nil else {
                print("❌ キャラクタリスティック探索エラー: \(error!.localizedDescription)")
                self.errorMessage = "キャラクタリスティック探索エラー: \(error!.localizedDescription)"
                return
            }

            guard let characteristics = service.characteristics else {
                print("⚠️ サービス \(service.uuid) にキャラクタリスティックが見つかりませんでした")
                return
            }

            // 発見されたキャラクタリスティックをログ出力
            print("📋 サービス \(service.uuid.uuidString) のキャラクタリスティック数: \(characteristics.count)")

            var foundNotifyCharacteristic = false

            for characteristic in characteristics {
                let uuidString = characteristic.uuid.uuidString
                let props = characteristic.properties

                var propDesc: [String] = []
                if props.contains(.read) { propDesc.append("read") }
                if props.contains(.write) { propDesc.append("write") }
                if props.contains(.writeWithoutResponse) { propDesc.append("writeWithoutResponse") }
                if props.contains(.notify) { propDesc.append("notify") }
                if props.contains(.indicate) { propDesc.append("indicate") }
                if props.contains(.broadcast) { propDesc.append("broadcast") }

                print("  キャラクタリスティック: \(uuidString)")
                print("    プロパティ: \(propDesc.joined(separator: ", "))")

                // 追加するキャラクタリスティックを保存
                if !self.discoveredCharacteristics.contains(characteristic.uuid) {
                    self.discoveredCharacteristics.append(characteristic.uuid)
                }

                // 通知/インジケート対応のキャラクタリスティックを購読
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    print("    → 通知を購読します...")
                    peripheral.setNotifyValue(true, for: characteristic)
                    foundNotifyCharacteristic = true

                    // オーディオキャラクタリスティックとして保存（通知購読済みの最初のもの）
                    if self.audioCharacteristic == nil {
                        self.audioCharacteristic = characteristic
                        print("    ✅ オーディオキャラクタリスティックとして設定しました")
                    }
                } else if characteristic.properties.contains(.read) {
                    // 読み取り可能なキャラクタリスティックを読み出して試す
                    print("    → 読み取りを試みます...")
                    peripheral.readValue(for: characteristic)
                }
            }

            // すべてのサービスとキャラクタリスティックの探索が完了したか確認
            if foundNotifyCharacteristic {
                self.connectionState = .ready
                print("✅ 準備完了 - 録音可能")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard error == nil else {
                print("❌ データ受信エラー: \(error!.localizedDescription)")
                self.errorMessage = "データ受信エラー: \(error!.localizedDescription)"
                return
            }

            guard let data = characteristic.value, !data.isEmpty else {
                print("⚠️ 空のデータを受信しました")
                return
            }

            print("📥 データを受信: \(data.count) bytes, キャラクタリスティック: \(characteristic.uuid.uuidString)")

            // 音声データを処理
            self.handleAudioData(data)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ データ書き込みエラー: \(error.localizedDescription)")
            } else {
                print("✅ データ書き込み成功: \(characteristic.uuid.uuidString)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let error = error {
                print("❌ 通知設定エラー: \(error.localizedDescription)")
                self.errorMessage = "通知設定エラー: \(error.localizedDescription)"
            } else {
                let state = characteristic.isNotifying ? "有効" : "無効"
                print("✅ 通知設定 \(state): \(characteristic.uuid.uuidString)")
            }
        }
    }

    private func handleAudioData(_ data: Data) {
        // デバイスから受信したオーディオデータを処理
        // データを16進数で表示（最初の32バイト）
        if data.count > 0 {
            let hexString = data.prefix(min(32, data.count)).map { String(format: "%02x", $0) }.joined(separator: " ")
            print("   データ (hex): \(hexString)")
        }

        if isRecording {
            // 録音中ならバッファに追加
            audioBuffer.append(data)
            print("   バッファサイズ: \(audioBuffer.count) bytes, 録音時間: \(recordingDuration)s")
        }
    }
}

/// Bluetooth デバイス情報
struct BluetoothDevice: Identifiable {
    let id: UUID
    let identifier: UUID
    let name: String
    let peripheral: CBPeripheral
    let rssi: Int
    let deviceType: BluetoothAudioService.DeviceType

    init(identifier: UUID, name: String, peripheral: CBPeripheral, rssi: Int, deviceType: BluetoothAudioService.DeviceType = .unknown) {
        self.id = identifier
        self.identifier = identifier
        self.name = name
        self.peripheral = peripheral
        self.rssi = rssi
        self.deviceType = deviceType
    }
}
