# 13. 汎用 BLE レコーダー & Wi-Fi 取り込み 設計

対象: iOS アプリ本体 / 依存: 10, 11

---

## 1. 目的

Omi/PLAUD 以外の AI レコーダー(名もなき BLE ボタン録音機、ESP32 自作機、その他)に順次対応できる汎用レイヤと、Wi-Fi/ローカルネットワーク経由のファイル取り込みを用意する。既存の `BluetoothAudioService.swift`(636行、汎用スキャン実装済み)をこのレイヤへ移行する。

## 2. RecorderDeviceManager(スキャン・接続・種別判定)

### 2.1 新規 `Memora/Core/Services/Devices/RecorderDeviceManager.swift`

```swift
import Foundation
import CoreBluetooth
import Observation

@Observable
@MainActor
final class RecorderDeviceManager: NSObject {
    enum Kind { case omi, plaud, generic }

    private(set) var discovered: [DiscoveredDevice] = []
    private(set) var connectedDevice: (any RecorderDevice)?
    private(set) var isScanning = false

    private var central: CBCentralManager!

    struct DiscoveredDevice: Identifiable {
        let id: UUID
        let name: String
        let rssi: Int
        let advertisedServices: [CBUUID]
        let peripheral: CBPeripheral
        var kind: Kind
    }

    func startScan(filter: Kind? = nil) {
        // Omi 指定時は Audio Service UUID で絞る。汎用時は nil(全件)。
        let services: [CBUUID]? = (filter == .omi) ? [OmiDevice.audioServiceUUID] : nil
        central.scanForPeripherals(withServices: services,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        isScanning = true
    }

    func connect(_ d: DiscoveredDevice) {
        central.connect(d.peripheral, options: nil)
    }

    /// 接続後、発見サービスから種別を確定しデバイスオブジェクトを生成
    private func makeDevice(for peripheral: CBPeripheral, services: [CBUUID]) -> any RecorderDevice {
        if services.contains(OmiDevice.audioServiceUUID) {
            return OmiDevice(peripheral: peripheral, central: central)
        }
        return GenericBLEDevice(peripheral: peripheral, central: central)
    }
}
```

### 2.2 種別判定ヒューリスティクス
1. アドバタイズ/接続後の Service UUID(最も確実。Omi は 19B10000…)。
2. デバイス名(補助。"omi"/"friend"/"plaud" 等)。
3. どれにも当たらなければ `GenericBLEDevice`。

## 3. GenericBLEDevice(既存 BluetoothAudioService の移行先)

既存 `BluetoothAudioService` は「全 notify 特性を購読して生バイトを WAV 保存」する汎用実装。これを `RecorderDevice` 準拠の `GenericBLEDevice` に移行する。

### 3.1 移行方針
- 既存のスキャン/接続/特性探索ロジックはそのまま流用。
- `startAudioStream(onBytes:)` で「notify 対応特性のうち最初に見つかったもの」を購読(既存の `audioCharacteristic` 選定ロジック)。
- コーデック不明のため、`getAudioCodec()` は `.unknown` を返し、UI で「生データ保存(実験的)」と明示。デコードせず生バイトを WAV(PCM 仮定)として保存する現行挙動を維持。
- **既存 `BluetoothAudioService` は消さず**、`GenericBLEDevice` として `RecorderDevice` に適合させるアダプタを被せる形が安全(既存の開発者向け BLE デバッグ機能を壊さない)。

### 3.2 コーデック自動推定(将来)
生バイトのパターン(パケットサイズ、TOC バイトの周期性)から Opus/PCM を推定するヒューリスティクスを `GenericBLEDevice` に足せる(Omi ドキュメントの「240バイトパケットに b8 が40バイト周期 → Opus」手法)。Phase 2+。

## 4. Wi-Fi / ローカルネットワーク経由のファイル取り込み

多くのレコーダーは「Wi-Fi でファイルサーバーを立てる」か「同一 LAN で HTTP/FTP 転送」を提供する。汎用取り込みとして:

### 4.1 対応する取り込み方式
| 方式 | 実装 |
|---|---|
| デバイスが HTTP サーバー | `URLSession` でファイル一覧取得 → ダウンロード |
| Bonjour/mDNS でデバイス発見 | `NetServiceBrowser` / `NWBrowser` で LAN 上のデバイス発見 |
| iOS Files アプリ経由 | 既存の `fileImporter`(実装済) |
| AirDrop / 共有 | iOS 標準の受け入れ |

### 4.2 汎用 LAN 取り込み `LANRecordingImporter.swift`(Phase 2)

```swift
import Network

/// 同一 LAN 上のレコーダー(HTTP ファイルサーバー型)から録音を取り込む。
@MainActor
final class LANRecordingImporter {
    /// Bonjour でデバイスを探す(デバイスが _http._tcp 等で広告する場合)
    func discoverDevices(serviceType: String = "_http._tcp") -> AsyncStream<NWEndpoint> { ... }

    /// デバイスの録音一覧を取得(デバイス固有のエンドポイント。設定で URL を指定)
    func listRecordings(baseURL: URL) async throws -> [StoredRecordingRef] { ... }

    /// ファイルをダウンロードして AudioFile 化
    func download(_ ref: StoredRecordingRef, from baseURL: URL,
                  onProgress: @escaping (Double) -> Void) async throws -> URL { ... }
}
```

`NSLocalNetworkUsageDescription`(10 参照)と、Bonjour サービスタイプを `Info.plist` の `NSBonjourServices` に追加が必要。

### 4.3 現実的な当面の解
デバイス固有の Wi-Fi プロトコルは千差万別。**Phase 2 では「デバイスの Wi-Fi 共有フォルダ/URL をユーザーが設定 → HTTP でファイル一覧取得・ダウンロード」の汎用 HTTP 取り込みのみ**を実装し、個別デバイス最適化は要望ベースで足す。

## 5. UI: デバイス追加フロー

```
デバイスと同期(Home FAB)
 → デバイス種別を選択
    ├─ Omi をスキャン(BLE)          → 11
    ├─ その他 BLE レコーダーをスキャン → GenericBLEDevice
    ├─ Wi-Fi/LAN のレコーダー         → LANRecordingImporter(URL 設定)
    └─ ファイルから取り込み           → 既存 fileImporter
```

## 6. AC

1. Omi 以外の notify 対応 BLE デバイスをスキャン・接続し、生データを WAV 保存できる(既存挙動の維持)。
2. 種別判定が Service UUID ベースで動く(Omi は Omi として、他は generic として扱われる)。
3. Wi-Fi 取り込み(Phase 2): HTTP サーバー型デバイスの URL を設定 → ファイル一覧 → ダウンロード → 文字起こし。
4. 既存の開発者向け BLE デバッグ機能が壊れていない。

## 7. フェーズ
- Phase 1: `RecorderDevice` 抽象 + `RecorderDeviceManager` + `GenericBLEDevice`(既存移行)。Omi(11)と同時。
- Phase 2: Wi-Fi/LAN 汎用取り込み、コーデック自動推定。
