import Foundation
import CoreBluetooth
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

    private let centralManager: CBCentralManager
    private var connectedPeripheral: CBPeripheral?
    private var audioCharacteristic: CBCharacteristic?
    private var audioBuffer = Data()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var audioFileURL: URL?

    // デバイスタイプ
    enum DeviceType {
        case omi
        case plaud
        case unknown
    }

    // Omi デバイスのサービス UUID（複数候補を探索）
    private let omiServiceUUIDs: [CBUUID] = [
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"), // Nordic UART Service（一般的）
        CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB"), // Device Information Service
        CBUUID(string: "0000181C-0000-1000-8000-00805F9B34FB"), // User Data Service
        CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")  // HM-10 互換
    ]

    // オーディオキャラクタリスティック UUID（候補）
    private let audioCharacteristicUUIDs: [CBUUID] = [
        CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"), // Nordic UART RX
        CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"), // Nordic UART TX
        CBUUID(string: "00002A58-0000-1000-8000-00805F9B34FB"), // Audio Control Point
        CBUUID(string: "00002A5D-0000-1000-8000-00805F9B34FB"), // Audio Input State
        CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")  // HM-10 Data
    ]

    // Plaud デバイスの UUID
    private let plaudServiceUUID = CBUUID(string: "00001800-0000-1000-8000-00805F9B34FB") // Generic Access
    private let plaudAudioServiceUUID = CBUUID(string: "00001803-0000-1000-8000-00805F9B34FB") // Generic Attribute
    private var plaudDeviceType: DeviceType = .unknown

    override init() {
        self.centralManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.centralManager.delegate = self
    }

    // MARK: - スキャン開始・停止

    func startScanning() {
        isScanning = true
        errorMessage = nil
        discoveredDevices.removeAll()
        discoveredServices.removeAll()
        discoveredCharacteristics.removeAll()

        // 既に接続されているデバイスがあれば切断
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        // すべてのデバイスをスキャン（サービス UUID 指定なし）
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // 10秒後にスキャン停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    // MARK: - 接続・切断

    func connect(to device: BluetoothDevice) {
        errorMessage = nil
        plaudDeviceType = device.deviceType
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        stopRecording()
        if let peripheral = connectedPeripheral {
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
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("Bluetooth: Powered On")
            case .poweredOff:
                print("Bluetooth: Powered Off")
                errorMessage = "Bluetoothがオフです"
            case .unauthorized:
                print("Bluetooth: Unauthorized")
                errorMessage = "Bluetooth の許可が必要です"
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            // 既に見つかったデバイスはスキップ
            if discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
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

            discoveredDevices.append(device)
            print("発見したデバイス: \(deviceName), タイプ: \(deviceType), RSSI: \(RSSI.intValue)")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("接続しました: \(peripheral.name ?? "Unknown")")
            isConnected = true
            isScanning = false
            stopScanning()

            // サービスを探索（デバイスタイプに応じて異なる UUID）
            peripheral.delegate = self

            switch plaudDeviceType {
            case .omi:
                // Omi デバイスは複数のサービス UUID を探索
                peripheral.discoverServices(omiServiceUUIDs)
            case .plaud:
                // Plaud デバイスはすべてのサービスを探索
                peripheral.discoverServices(nil)
            case .unknown:
                // 未知のデバイスはすべてのサービスを探索
                peripheral.discoverServices(nil)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("切断しました: \(peripheral.name ?? "Unknown")")

            isConnected = false
            connectedPeripheral = nil
            audioCharacteristic = nil

            if let error = error {
                errorMessage = "切断エラー: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("接続失敗: \(peripheral.name ?? "Unknown"), Error: \(error?.localizedDescription ?? "Unknown")")

            isConnected = false
            errorMessage = "接続失敗: \(error?.localizedDescription ?? "不明なエラー")"
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothAudioService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                print("サービス探索エラー: \(error!.localizedDescription)")
                errorMessage = "サービス探索エラー: \(error!.localizedDescription)"
                return
            }

            guard let services = peripheral.services else { return }

            // 発見されたサービス UUID をログ出力
            print("発見されたサービス数: \(services.count)")
            var discoveredUUIDs: [CBUUID] = []
            for service in services {
                print("  サービス UUID: \(service.uuid)")
                discoveredUUIDs.append(service.uuid)

                // キャラクタリスティックを探索
                peripheral.discoverCharacteristics(nil, for: service)
            }

            // 発見されたサービスを保存（UI に表示可能）
            discoveredServices = discoveredUUIDs
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                print("キャラクタリスティック探索エラー: \(error!.localizedDescription)")
                errorMessage = "キャラクタリスティック探索エラー: \(error!.localizedDescription)"
                return
            }

            guard let characteristics = service.characteristics else { return }

            // 発見されたキャラクタリスティックをログ出力
            print("サービス \(service.uuid) のキャラクタリスティック数: \(characteristics.count)")
            for characteristic in characteristics {
                print("  キャラクタリスティック UUID: \(characteristic.uuid)")
                print("    プロパティ: \(characteristic.properties)")

                // 追加するキャラクタリスティックを保存
                if !discoveredCharacteristics.contains(characteristic.uuid) {
                    discoveredCharacteristics.append(characteristic.uuid)
                }

                // 通知/インジケート対応のキャラクタリスティックを購読
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: characteristic)

                    // オーディオキャラクタリスティックとして保存（通知購読済みの最初のもの）
                    if audioCharacteristic == nil {
                        audioCharacteristic = characteristic
                        print("通知購読開始: \(characteristic.uuid)")
                    }
                } else if characteristic.properties.contains(.read) {
                    // 読み取り可能なキャラクタリスティックを読み出して試す
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                print("データ受信エラー: \(error!.localizedDescription)")
                return
            }

            guard let data = characteristic.value else { return }

            // 音声データを処理
            handleAudioData(data)
        }
    }

    private func handleAudioData(_ data: Data) {
        // デバイスから受信したオーディオデータを処理
        print("受信した音声データサイズ: \(data.count) bytes")

        if isRecording {
            // 録音中ならバッファに追加
            audioBuffer.append(data)
            print("バッファサイズ: \(audioBuffer.count) bytes, 録音時間: \(recordingDuration)s")
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
