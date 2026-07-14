# 11. Omi デバイス連携 完全実装設計

対象: iOS アプリ本体 / 依存: 10(RecorderDevice プロトコル)
出典: Omi 公式ドキュメント(docs.omi.me/doc/integrations)、`BasedHardware/omi` GitHub、Omi firmware パターン

> Omi はオープンソースでプロトコルが公開されているため、リバースエンジニアリング不要でそのまま実装できる。以下の UUID・パケット形式はすべて公開情報。

---

## 1. Omi の BLE 仕様(公開情報・検証済み)

### 1.1 Service / Characteristic UUID

| 種別 | UUID | プロパティ | 用途 |
|---|---|---|---|
| Audio Service | `19B10000-E8F2-537E-4F6C-D104768A1214` | — | 音声ストリーミングサービス |
| Audio Data | `19B10001-E8F2-537E-4F6C-D104768A1214` | notify | 音声データ受信(本命) |
| Codec Type | `19B10002-E8F2-537E-4F6C-D104768A1214` | read | コーデック種別取得 |
| Battery Service | `0x180F`(標準) | read/notify | バッテリー残量 |
| Device Info | `0x180A`(標準) | read | ファーム/モデル情報 |

### 1.2 コーデック種別(Codec Type 特性を read した1バイト値)

| 値 | コーデック |
|---|---|
| `0` | PCM 16-bit, 16 kHz, mono |
| `1` | PCM 16-bit, 8 kHz, mono |
| `10` | µ-law, 16 kHz, 8-bit mono |
| `11` | µ-law, 8 kHz, 8-bit mono |
| `20`(一般的) | Opus, 16 kHz, mono |

■確認せよ: 実機の Codec Type 値。Omi Dev Kit 2 は Opus が既定。値のマッピングは firmware バージョンで変わり得るため、read した値をログ出力して確認する。

### 1.3 音声パケット形式(Audio Data の notify ペイロード)

```
[ヘッダ 3バイト][音声ペイロード]
 - バイト 0-1: パケット番号(リトルエンディアン, 0-65535)
 - バイト 2  : パケット内インデックス(フラグメント位置)
 - バイト 3以降: 音声データ(コーデック依存)
```

- BLE MTU を超えるフレームは複数 notify に**フラグメント分割**される。パケット番号とインデックスで再結合する。
- Opus の場合、ペイロードは Opus フレーム。TOC バイト(先頭)を持つ。

## 2. 実装: OmiDevice

### 2.1 新規ファイル `Memora/Core/Services/Devices/OmiDevice.swift`

```swift
import Foundation
import CoreBluetooth

final class OmiDevice: NSObject, RecorderDevice {
    static let audioServiceUUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
    static let audioDataUUID    = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
    static let codecTypeUUID    = CBUUID(string: "19B10002-E8F2-537E-4F6C-D104768A1214")
    static let batteryServiceUUID = CBUUID(string: "180F")
    static let batteryLevelUUID   = CBUUID(string: "2A19")

    let identifier: UUID
    var displayName: String { peripheral.name ?? "Omi" }
    var isConnected: Bool { peripheral.state == .connected }

    private let peripheral: CBPeripheral
    private let central: CBCentralManager
    private var audioDataChar: CBCharacteristic?
    private var codecChar: CBCharacteristic?
    private var batteryChar: CBCharacteristic?

    private var onBytes: ((Data) -> Void)?
    private var codecContinuation: CheckedContinuation<RecorderAudioCodec, Error>?
    private var reassembler = OmiPacketReassembler()

    init(peripheral: CBPeripheral, central: CBCentralManager) {
        self.identifier = peripheral.identifier
        self.peripheral = peripheral
        self.central = central
        super.init()
        peripheral.delegate = self
    }

    func getAudioCodec() async throws -> RecorderAudioCodec {
        // codecChar を read → didUpdateValue で continuation を resume
        guard let codecChar else { return .opus(sampleRate: 16000) }  // 既定
        return try await withCheckedThrowingContinuation { cont in
            self.codecContinuation = cont
            peripheral.readValue(for: codecChar)
        }
    }

    func startAudioStream(onBytes: @escaping @Sendable (Data) -> Void) async throws {
        self.onBytes = onBytes
        guard let audioDataChar else { throw RecorderError.characteristicNotFound }
        peripheral.setNotifyValue(true, for: audioDataChar)
    }

    func stopAudioStream() async {
        if let audioDataChar { peripheral.setNotifyValue(false, for: audioDataChar) }
        onBytes = nil
    }

    func retrieveBatteryLevel() async -> Int? {
        guard let batteryChar else { return nil }
        // read して didUpdateValue で拾う(簡略化のため省略。continuation 方式)
        peripheral.readValue(for: batteryChar)
        return lastBatteryLevel
    }
    private var lastBatteryLevel: Int?

    // Omi は streaming デバイスなのでファイル同期は非対応
    func listStoredRecordings() async throws -> [StoredRecordingRef] { [] }
    func downloadRecording(_ ref: StoredRecordingRef,
                           onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        throw RecorderError.notSupported
    }
}

extension OmiDevice: CBPeripheralDelegate {
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for service in p.services ?? [] {
            p.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            switch c.uuid {
            case Self.audioDataUUID:  audioDataChar = c
            case Self.codecTypeUUID:  codecChar = c
            case Self.batteryLevelUUID: batteryChar = c
            default: break
            }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if c.uuid == Self.codecTypeUUID {
            let codec = Self.parseCodec(c.value)
            codecContinuation?.resume(returning: codec)
            codecContinuation = nil
        } else if c.uuid == Self.audioDataUUID {
            guard let value = c.value else { return }
            // ヘッダ除去 + フラグメント再結合
            if let frame = reassembler.feed(value) {
                onBytes?(frame)
            }
        } else if c.uuid == Self.batteryLevelUUID {
            lastBatteryLevel = c.value?.first.map { Int($0) }
        }
    }

    static func parseCodec(_ data: Data?) -> RecorderAudioCodec {
        guard let b = data?.first else { return .opus(sampleRate: 16000) }
        switch b {
        case 0:  return .pcm16(sampleRate: 16000)
        case 1:  return .pcm16(sampleRate: 8000)
        case 10: return .muLaw(sampleRate: 16000)
        case 11: return .muLaw(sampleRate: 8000)
        default: return .opus(sampleRate: 16000)   // 20 等
        }
    }
}
```

### 2.2 パケット再結合 `OmiPacketReassembler.swift`

```swift
/// Omi 音声パケットのヘッダ除去とフラグメント再結合。
/// [pktNum(2, LE)][index(1)][payload...] を組み立て、
/// 完全な音声フレーム(Opus フレーム or PCM チャンク)を返す。
struct OmiPacketReassembler {
    private var currentPacketNum: UInt16?
    private var buffer = Data()

    mutating func feed(_ raw: Data) -> Data? {
        guard raw.count > 3 else { return nil }
        let pktNum = UInt16(raw[0]) | (UInt16(raw[1]) << 8)
        let index = raw[2]
        let payload = raw.subdata(in: 3..<raw.count)

        if index == 0 {
            // 新しいフレーム開始: 前フレームを確定して返す
            let completed = buffer.isEmpty ? nil : buffer
            buffer = payload
            currentPacketNum = pktNum
            return completed
        } else {
            // 継続フラグメント
            buffer.append(payload)
            return nil
        }
    }
}
```

■確認せよ: フラグメント境界の判定方法。上記は「index==0 で新フレーム開始」の一般的仮定。実機で index の増え方(0,1,2… か)を Wireshark/ログで確認し、フレーム区切りロジックを合わせる。Omi firmware は「1 notify = 複数 Opus フレーム(各40バイト等)」のパターンもあるため、Opus の場合は TOC バイトでフレーム分割する実装(§3)と併用する。

## 3. Opus デコード

iOS に Opus デコーダは標準搭載されていない。**libopus を SPM/CocoaPods で導入**する。

### 3.1 依存追加
- SPM: `swift-opus` 系ラッパー、または libopus C ライブラリを直接 bridging。
- ■確認せよ: 既存 `project.yml`(XcodeGen)への依存追加方法。Package 依存を `packages:` に追加し、target の `dependencies:` に含める。

### 3.2 `OpusStreamDecoder.swift`

```swift
import Foundation
// import Copus  // libopus bridging（導入方法は環境依存）

/// Omi の Opus ストリームを PCM16 にデコードする薄いラッパー。
final class OpusStreamDecoder {
    private var decoder: OpaquePointer?   // OpusDecoder*
    private let sampleRate: Int32 = 16000
    private let channels: Int32 = 1

    init?() {
        var err: Int32 = 0
        decoder = opus_decoder_create(sampleRate, channels, &err)
        guard err == OPUS_OK, decoder != nil else { return nil }
    }

    deinit { if let decoder { opus_decoder_destroy(decoder) } }

    /// 1 Opus フレーム → PCM16 Data。複数フレーム連結時は呼び出し側で分割。
    func decode(_ opusFrame: Data) -> Data? {
        guard let decoder else { return nil }
        let maxSamples = 960   // 60ms @ 16kHz
        var pcm = [Int16](repeating: 0, count: maxSamples)
        let decoded = opusFrame.withUnsafeBytes { raw -> Int32 in
            opus_decode(decoder,
                        raw.bindMemory(to: UInt8.self).baseAddress,
                        Int32(opusFrame.count),
                        &pcm, Int32(maxSamples), 0)
        }
        guard decoded > 0 else { return nil }
        return pcm.prefix(Int(decoded)).withUnsafeBytes { Data($0) }
    }
}
```

■確認せよ: libopus のリンク方法(iOS 向けビルド済み xcframework が最も楽)。導入が重い場合、Phase 1 では **PCM コーデックの Omi デバイスのみ対応**(Codec Type 0/1)とし、Opus は Phase 1.5 に回す判断も可(Opus 非対応でも動くデバイスはある)。

## 4. µ-law デコード(補助)

```swift
enum MuLaw {
    static func toPCM16(_ data: Data) -> Data {
        var out = Data(capacity: data.count * 2)
        for byte in data {
            let sample = decode(byte)
            withUnsafeBytes(of: sample.littleEndian) { out.append(contentsOf: $0) }
        }
        return out
    }
    private static func decode(_ u: UInt8) -> Int16 {
        let u = ~u
        let sign = Int(u & 0x80)
        let exponent = Int((u >> 4) & 0x07)
        let mantissa = Int(u & 0x0F)
        var sample = ((mantissa << 3) + 0x84) << exponent
        sample -= 0x84
        return Int16(sign != 0 ? -sample : sample)
    }
}
```

## 5. デバイス種別判定とスキャン

`RecorderDeviceManager`(13 で定義)のスキャンで、Omi の Audio Service UUID をアドバタイズしているデバイス、または名前に "Omi"/"Friend" を含むデバイスを Omi と判定。確実なのは **接続後に Audio Service UUID の有無で確定**する。

```swift
central.scanForPeripherals(
    withServices: [OmiDevice.audioServiceUUID],   // Omi に絞る
    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
)
```

## 6. 受け入れ条件(AC)

1. Omi Dev Kit を電源 ON・公式アプリ未接続の状態でスキャン → デバイス一覧に表示。
2. 接続 → Codec Type を read しログに出力(0/1/20 等)。
3. 録音開始 → Audio Data の notify を受信、パケット再結合 → デコード → PCM 蓄積。
4. 録音停止 → WAV 化 → `AudioFile` 作成 → 既存パイプラインで文字起こしが走る。
5. 生成された WAV を再生して**実際の音声として聞こえる**(コーデック/ヘッダ処理が正しい最終検証)。
6. バッテリー残量が表示される。
7. 切断・再接続が既存 `BluetoothAudioService` と同等に動く。

## 7. テスト戦略

- 実機(Omi)が必要な統合テストと、ロジック単体(`OmiPacketReassembler` / `MuLaw` / codec parse)の単体テストを分離。
- `OmiPacketReassembler` は固定バイト列でフレーム再結合を検証(実機不要)。
- `MuLaw.toPCM16` は既知の µ-law→PCM 変換表で検証。
- Opus は既知の Opus フレーム(テストベクタ)→ PCM で検証。

## 8. 参考リンク

- 統合ガイド: https://docs.omi.me/doc/integrations
- Omi 本体: https://github.com/BasedHardware/omi
- 最小 fork(音声キャプチャに集中、参考実装): https://github.com/unforced/my-omi
