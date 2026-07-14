# 10. デバイス連携 全体設計

対象: iOS アプリ本体 / STT コアには触れない(取り込んだ音声は既存パイプラインに渡すだけ)

---

## 1. 接続方式の全体像

AI レコーダーとアプリの接続には大きく3つの経路がある。デバイスごとに使える経路が違う。

| 経路 | 仕組み | 対応デバイス | Memora 現状 |
|---|---|---|---|
| **A. BLE ストリーミング** | デバイスが録音中の音声を BLE で逐次送信。アプリがリアルタイム受信 | Omi(Opus)、一部の常時録音ウェアラブル | 汎用受信のみ実装済 |
| **B. BLE / Wi-Fi ファイル同期** | デバイス内蔵ストレージに録音 → 後で BLE か Wi-Fi でファイル転送 | PLAUD(公式SDK)、多くのボタン録音機 | 未実装 |
| **C. 手動インポート** | デバイスの公式アプリ/PCでエクスポート → Memora に取り込み | ほぼ全機種 | 実装済(ファイルインポート) |

設計方針: **A(Omi)を本命実装**、**B は PLAUD 公式 SDK と Wi-Fi 汎用**、**C は既存を維持**。どの経路でも最終的に「`AudioFile` を作って既存の文字起こしパイプラインへ渡す」ところに収束させる。

## 2. アーキテクチャ: デバイス抽象化レイヤ

現状の `BluetoothAudioService`(1クラスに全部入り)を、デバイス種別ごとに差し替え可能な構造へ発展させる。Omi の Flutter 実装(`DeviceConnection` 抽象クラス + デバイス別サブクラス + Factory)の設計をそのまま Swift に写す。

```
RecorderDevice (protocol)          ← デバイス共通インターフェース
├── OmiDevice                      ← 11 で実装(BLE streaming + Opus)
├── PlaudDevice                    ← 12(公式SDK or インポート)
├── GenericBLEDevice               ← 13(既存 BluetoothAudioService を移行)
└── (将来: Limitless, その他)

RecorderDeviceManager              ← スキャン・接続・種別判定・再接続
RecorderAudioSink                  ← 受信音声を AudioFile 化して既存パイプラインへ
```

### 2.1 共通プロトコル定義(新規 `Memora/Core/Services/Devices/RecorderDevice.swift`)

```swift
import Foundation
import CoreBluetooth

/// AI レコーダーの音声コーデック
enum RecorderAudioCodec: Sendable {
    case pcm16(sampleRate: Int)     // 例: pcm16(16000)
    case muLaw(sampleRate: Int)
    case opus(sampleRate: Int)      // 通常 16000
    case unknown
}

/// レコーダーとの接続を抽象化する共通インターフェース。
/// Omi の Flutter 実装 DeviceConnection を Swift に写したもの。
protocol RecorderDevice: AnyObject {
    var identifier: UUID { get }
    var displayName: String { get }
    var isConnected: Bool { get }

    /// 音声コーデックを取得(BLE の Codec 特性を read する等)
    func getAudioCodec() async throws -> RecorderAudioCodec

    /// 音声バイト列の受信購読を開始。ハンドラには生バイト(コーデック依存)が渡る
    func startAudioStream(onBytes: @escaping @Sendable (Data) -> Void) async throws

    func stopAudioStream() async

    /// バッテリー残量(標準 Battery Service 0x180F 等)
    func retrieveBatteryLevel() async -> Int?

    /// デバイス内の録音ファイル一覧(ファイル同期型のみ。streaming 型は空)
    func listStoredRecordings() async throws -> [StoredRecordingRef]

    /// ファイル同期型: 指定録音をダウンロード
    func downloadRecording(_ ref: StoredRecordingRef,
                           onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

struct StoredRecordingRef: Sendable, Identifiable {
    let id: String
    let name: String
    let durationSec: Double?
    let sizeBytes: Int?
    let createdAt: Date?
}
```

### 2.2 受信音声を既存パイプラインへ橋渡し(新規 `RecorderAudioSink.swift`)

streaming 型(Omi)は「無音区間で区切って1録音にまとめる」か「ユーザーが停止するまで1ファイル」かを選ぶ。当面は**ユーザーが録音開始/停止を明示操作**する単純モデルにする(常時録音は電池・プライバシー・法規で重いので Phase 2)。

```swift
@MainActor
final class RecorderAudioSink {
    private var pcmAccumulator = Data()
    private var codec: RecorderAudioCodec = .unknown
    private let decoder: OpusStreamDecoder?   // 11 参照。opus 時のみ

    /// streaming デバイスからのバイト列を受け取り、PCM に正規化して蓄積
    func ingest(_ bytes: Data) {
        switch codec {
        case .opus:
            if let pcm = decoder?.decode(bytes) { pcmAccumulator.append(pcm) }
        case .pcm16:
            pcmAccumulator.append(bytes)      // ヘッダ除去は 11 参照
        case .muLaw:
            pcmAccumulator.append(MuLaw.toPCM16(bytes))
        case .unknown:
            break
        }
    }

    /// 録音停止時: WAV 化 → AudioFile 作成 → 既存の文字起こし導線へ
    func finalizeToAudioFile(title: String, modelContext: ModelContext) -> AudioFile? {
        guard !pcmAccumulator.isEmpty else { return nil }
        let wav = WAVWriter.write(pcm16: pcmAccumulator, sampleRate: codec.sampleRate ?? 16000)
        // 既存の録音保存フロー(RecordingView 保存後と同じ)に合流させる。
        // AudioFile を作り、sourceType = .bluetoothDevice 等を設定し、
        // 既存の「保存後に自動文字起こし」パスを呼ぶ。
        ...
    }
}
```

## 3. 権限と Info.plist

BLE と(将来の)ローカルネットワーク Wi-Fi 転送のため、以下を追加:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>AI レコーダーと接続して録音を取り込むために Bluetooth を使用します。</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Wi-Fi 経由でレコーダーから録音ファイルを転送するために使用します。</string>
<key>NSMicrophoneUsageDescription</key>
<string>録音のためにマイクを使用します。</string>
```

BLE のバックグラウンド常時接続が必要な場合(streaming 常時録音)は `UIBackgroundModes` に `bluetooth-central` を追加。ただし審査で用途説明が必要になるため Phase 2 で判断。

## 4. UI 導線(既存 DeviceDetailView の発展)

既存 `DeviceDetailView` はデバイス詳細を表示する。ここへ:
- 「デバイスを追加」→ 種別選択(Omi / PLAUD / その他 BLE)→ スキャン → 接続
- 接続済みデバイスのカード(バッテリー、接続状態、録音ボタン or 同期ボタン)
- ファイル同期型は「デバイス内の録音一覧」→ 選択ダウンロード → 自動文字起こし

画面遷移は先の「画面遷移設計パッケージ」の Home FAB「PLAUD から同期」を「デバイスと同期」に一般化して接続する。

## 5. フェーズ分け

| Phase | 内容 | 対応ドキュメント |
|---|---|---|
| 1 | デバイス抽象化レイヤ + Omi BLE streaming(Opus)対応 | 11 |
| 2 | 汎用 BLE レコーダー(既存サービス移行)+ Wi-Fi ファイル取り込み | 13 |
| 3 | PLAUD 公式 SDK 評価・統合(可否判断含む) | 12 |
| 4 | 常時録音・バックグラウンドストリーミング(法規・電池対応) | 将来 |

## 6. 法的注意(再掲・重要)

- PLAUD の独自 BLE を**リバースエンジニアリングしない**(規約違反)。
- 録音は地域の録音同意法に従う。UI で録音時に周囲への配慮・同意取得を促す。
