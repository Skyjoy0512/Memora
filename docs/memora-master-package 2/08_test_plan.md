# 08. テスト整備 詳細設計書

Lane: E (QA) / 依存: 02(withDeadline)、07(checkpoint)実装後に該当節を追加
対応 PR: PR-E1(02 と同時期)、PR-E2(07 後)

既存テスト基盤(確認済み): `MemoraTests/` に Swift Testing / XCTest ベースのテスト群(`STTPreflightTests`, `FileDetailViewModelTests` 等)。■確認: 既存テストが XCTest か Swift Testing(`@Test`)か — **既存の流儀に合わせる**(以下は XCTest 表記。Swift Testing なら機械的に読み替え)。

---

## 1. テスト用フェイクの整備(新規 `MemoraTests/Services/STTTestDoubles.swift`)

`STTService` は `readiness: STTReadinessProtocol` と `chunkerFactory: () -> AudioChunkerProtocol` を注入可能(確認済み)。バックエンド実行(`STTBackendExecutor`)は private で注入不可のため、**チャンク/マージ/イベント系のテストは chunker+実ファイルで、実行系は withDeadline 単体で**カバーする方針。

```swift
final class FakeReadiness: STTReadinessProtocol {
    var isReady: Bool { get async { true } }
    var supportedLanguages: [String] { get async { ["ja", "en"] } }
    var requiresDownload: Bool { get async { false } }
    func prepare() async throws {}
}

/// 固定チャンク構成を返すフェイク。実音声ファイル不要。
final class FakeChunker: AudioChunkerProtocol {
    let chunks: [AudioChunk]
    private(set) var cleanupCalled = false
    init(chunks: [AudioChunk]) { self.chunks = chunks }

    func analyzeAndChunk(fileURL: URL, onProgress: AudioChunkProgressHandler?) async throws -> [AudioChunk] {
        onProgress?(chunks.count, chunks.count)
        return chunks
    }
    func cleanup(chunks: [AudioChunk]) async { cleanupCalled = true }
}
```

テスト用音声: `MemoraTests/Fixtures/` に 3〜5 秒の無音でない WAV を追加(生成方法: `scripts` で `afconvert` するか、テスト内で `AVAudioFile` 書き出し。**バイナリ追加が嫌なら setUp で正弦波 WAV をプログラム生成** — こちらを推奨)。

```swift
enum TestAudioFactory {
    /// 指定秒数の 440Hz 正弦波 WAV を一時ディレクトリに生成
    static func makeSineWAV(seconds: Double, sampleRate: Double = 16_000) throws -> URL { ... }
    /// 前半 speech 代替(正弦波)+後半無音の WAV
    static func makeToneThenSilenceWAV(toneSeconds: Double, silenceSeconds: Double) throws -> URL { ... }
}
```

---

## 2. PR-E1a: `STTDeadlineTests`(02 §4 の withDeadline)

新規 `MemoraTests/Services/STTDeadlineTests.swift`:

```swift
final class STTDeadlineTests: XCTestCase {

    func test_immediateSuccess_returnsValue() async throws {
        let value = try await withDeadline(seconds: 5) { 42 }
        XCTAssertEqual(value, 42)
    }

    func test_deadlineExceeded_throwsDeadlineError_andCancelsOperation() async {
        let started = expectation(description: "op started")
        let sawCancel = LockedBox(false)   // NSLock ラッパ(同ファイルに定義)
        do {
            _ = try await withDeadline(seconds: 0.2) {
                started.fulfill()
                // 協力的な長時間作業
                for _ in 0..<100 {
                    if Task.isCancelled { sawCancel.set(true); break }
                    try? await Task.sleep(for: .milliseconds(50))
                }
                return 0
            }
            XCTFail("should throw")
        } catch {
            XCTAssertTrue(error is DeadlineExceededError)
        }
        await fulfillment(of: [started], timeout: 1)
        // cancel 伝播はベストエフォート: 500ms 以内に観測できること
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(sawCancel.get())
    }

    func test_lateCompletionAfterDeadline_isDiscarded_noDoubleResume() async {
        // 期限 0.1s、作業 0.4s。throw 後にクラッシュしないこと自体が検証
        do {
            _ = try await withDeadline(seconds: 0.1) {
                try? await Task.sleep(for: .milliseconds(400))
                return 1
            }
            XCTFail("should throw")
        } catch { }
        // 遅延完了が resume を試みる時間まで待つ(double-resume なら fatal)
        try? await Task.sleep(for: .milliseconds(600))
    }

    func test_onDeadlineHook_isInvokedExactlyOnceOnTimeout() async {
        let count = LockedBox(0)
        _ = try? await withDeadline(seconds: 0.1, onDeadline: { count.mutate { $0 += 1 } }) {
            try? await Task.sleep(for: .seconds(1))
            return 0
        }
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(count.get(), 1)
    }

    func test_operationThrows_propagatesOriginalError() async {
        struct Boom: Error {}
        do {
            _ = try await withDeadline(seconds: 5) { throw Boom() }
            XCTFail()
        } catch {
            XCTAssertTrue(error is Boom)
        }
    }
}
```

## 3. PR-E1b: カバレッジ+無音判定テスト(02 §5)

新規 `MemoraTests/Services/AudioSilenceProbeTests.swift`:

```swift
final class AudioSilenceProbeTests: XCTestCase {

    func test_silenceRegion_hasNearZeroRMS() throws {
        let url = try TestAudioFactory.makeToneThenSilenceWAV(toneSeconds: 2, silenceSeconds: 3)
        let rms = AudioSilenceProbe.averageRMS(url: url, startSec: 2.2, endSec: 5.0)
        XCTAssertNotNil(rms)
        XCTAssertLessThan(rms!, 0.008)
    }

    func test_toneRegion_hasAudibleRMS() throws {
        let url = try TestAudioFactory.makeToneThenSilenceWAV(toneSeconds: 2, silenceSeconds: 3)
        let rms = AudioSilenceProbe.averageRMS(url: url, startSec: 0.2, endSec: 1.8)
        XCTAssertGreaterThan(rms ?? 0, 0.05)
    }

    func test_invalidRange_returnsNil() throws {
        let url = try TestAudioFactory.makeSineWAV(seconds: 1)
        XCTAssertNil(AudioSilenceProbe.averageRMS(url: url, startSec: 3, endSec: 2))
    }
}
```

判定分岐(coverage×RMS)自体は `STTBackendExecutor` private のため単体化しない。分岐を関数抽出できる場合(`static func shouldRetryOnServer(coverage: Double, tailRMS: Float?) -> Bool` を `STTSupportTypes` に置く実装を 02 実装者に推奨)、以下を追加:

```swift
func test_lowCoverage_silentTail_doesNotRetry()
func test_lowCoverage_audibleTail_retries()
func test_highCoverage_neverRetries()
```

## 4. PR-E1c: STTService イベント/マージ結合テスト

新規 `MemoraTests/Services/STTServiceEventTests.swift`。実バックエンド(SFSpeech)は simulator で不安定なため、**API モード + モック不可**の制約から、ここでは「チャンク分割なし(90 秒未満)の実ファイル + ローカル」ではなく、**マージとタイムスタンプオフセットの純関数部分**を検証する。`merge` は private のため、02/03 実装時に `STTSupportTypes` へ抽出することを推奨(`enum STTMerge { static func merge(chunks:results:preferredLanguage:) -> TranscriptionResult }`)。抽出後:

```swift
final class STTMergeTests: XCTestCase {

    func test_merge_offsetsSegmentTimesByChunkStart() {
        let chunks = [
            AudioChunk(index: 0, startSec: 0,  endSec: 90, url: URL(fileURLWithPath: "/tmp/a"), isTemporary: true),
            AudioChunk(index: 1, startSec: 90, endSec: 150, url: URL(fileURLWithPath: "/tmp/b"), isTemporary: true)
        ]
        let results = [
            TranscriptionResult(fullText: "こんにちは", language: "ja", segments: [
                TranscriptionSegment(id: "s0", speakerLabel: "", startSec: 1, endSec: 3, text: "こんにちは")
            ]),
            TranscriptionResult(fullText: "さようなら", language: "ja", segments: [
                TranscriptionSegment(id: "s0", speakerLabel: "", startSec: 2, endSec: 4, text: "さようなら")
            ])
        ]
        let merged = STTMerge.merge(chunks: chunks, results: results, preferredLanguage: "ja")
        XCTAssertEqual(merged.segments.count, 2)
        XCTAssertEqual(merged.segments[1].startSec, 92, accuracy: 0.001)
        XCTAssertEqual(merged.segments[1].endSec, 94, accuracy: 0.001)
        XCTAssertEqual(merged.fullText, "こんにちは\nさようなら")
        XCTAssertEqual(merged.language, "ja")
    }

    func test_merge_emptyResults_producesEmptyText() { ... }
    func test_merge_languageFallsBackToFirstResult_whenPreferredNil() { ... }
}
```

## 5. PR-E2: チェックポイントテスト(07 実装後)

新規 `MemoraTests/Services/TranscriptionCheckpointTests.swift`(in-memory ModelContainer は既存 `TestHelpers.swift` の流儀に従う):

```swift
@MainActor
final class TranscriptionCheckpointStoreTests: XCTestCase {
    var container: ModelContainer!
    var store: TranscriptionCheckpointStore!

    override func setUp() async throws {
        container = try TestHelpers.makeInMemoryContainer()   // ■確認: 既存ヘルパ名
        store = TranscriptionCheckpointStore(modelContext: container.mainContext)
    }

    func test_saveAndLoad_roundTrip() {
        let id = UUID()
        let result = CheckpointChunkResult(fullText: "a", language: "ja", segments: [])
        store.save(audioFileID: id, fingerprint: "100-60-2", totalChunks: 2, chunkIndex: 0, result: result)
        let loaded = store.load(audioFileID: id, fingerprint: "100-60-2")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0]?.fullText, "a")
    }

    func test_load_withMismatchedFingerprint_discardsCheckpoint() {
        let id = UUID()
        store.save(audioFileID: id, fingerprint: "100-60-2", totalChunks: 2, chunkIndex: 0,
                   result: .init(fullText: "a", language: "ja", segments: []))
        let loaded = store.load(audioFileID: id, fingerprint: "999-60-2")
        XCTAssertTrue(loaded.isEmpty)
        // 破棄されていること
        XCTAssertTrue(store.load(audioFileID: id, fingerprint: "100-60-2").isEmpty)
    }

    func test_delete_removesRecord() { ... }
    func test_multipleChunks_accumulate() { ... }
    func test_dtoRoundTrip_preservesSegments() {
        // CheckpointChunkResult(from:) → toTranscriptionResult() の等価性
    }
}
```

## 6. 手動 QA マトリクス(リリース前回帰、全 PR 合流後)

| シナリオ | ローカル | API |
|---|---|---|
| 30 秒録音 → 文字起こし → 要約 | ✅ | ✅ |
| 5 分録音(複数チャンク)完走 | ✅ | ✅ |
| 5 分録音 → 途中 kill → 再実行(再開ログ) | ✅ | ✅ |
| 文字起こし中に BG 移行(30 秒)→ 復帰 | ✅ | ✅ |
| 権限拒否 → 失敗アラート「設定を開く」 | ✅ | — |
| タイムアウト → 「API モードで再試行」 | ✅ | — |
| 末尾 60 秒無音 → server 再試行なしログ | ✅ | — |
| セグメントタップシーク / 再生追従スクロール | ✅ | ✅ |
| SRT export → 外部プレイヤーで時刻一致 | ✅(SFSpeech) | ✅(verbose) |
| 後付け話者分離 → 再起動後もラベル保持 | ✅ | — |
| FAB 4 導線 / 生成 sheet 全分岐 / 設定階層 | ✅ | ✅ |

## 7. CI 注意

- 新規テストは simulator 上で外部ネットワーク・マイク権限・実 STT を要求しない構成にする(上記はすべて満たす)。
- `TestAudioFactory` の WAV 生成は毎回 `FileManager.default.temporaryDirectory` を使い、tearDown で削除。
