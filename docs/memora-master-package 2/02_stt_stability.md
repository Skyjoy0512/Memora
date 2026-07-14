# 02. STT 安定化(P0)詳細設計書

Lane: B (STT コア) / **STT コア保護ファイルの編集を伴う正式な STT タスク**
依存: なし / 対応 PR: PR-B1 〜 PR-B4

> boundary 遵守: 本書の変更は `STTService.swift` と `STTSupportTypes.swift` に閉じる。
> バックエンド選択順(SpeechAnalyzer → SFSpeechRecognizer on-device → server → API)は **変更しない**。
> 保存フォーマット・話者分離ロジックは **変更しない**。
> PR 説明には CLAUDE.md §10 の報告項目(選択順への影響=なし、各バックエンドへの影響、話者分離/保存形式への影響=なし、build/test/log)を必ず記載。

---

## 1. 修正対象の不具合(現状コードで確認済み)

| ID | 不具合 | 影響 |
|---|---|---|
| B-1 | SFSpeechRecognizer タイムアウト時に `clearRecognitionTask()`(参照 nil 化のみ)が呼ばれ、`cancelRecognitionTask()` は**全コードで未使用**。認識タスクが裏で走り続ける | リソースリーク、破棄済みチャンクへの partialResult 発火、直列チャンクの二重実行、発熱、クラッシュ温床 |
| B-2 | `beginBackgroundTask` の expiration handler がコメント(「タスクをキャンセル」)に反して `endBackgroundTask` しか呼ばず、STT タスクを止めない | BG 猶予切れ後の suspend で状態不整合、復帰時 UI ゾンビ |
| B-3 | continuation + `DispatchWorkItem` + `NSLock`/`didResume` の同型実装が3箇所に手書き重複(SFSpeech / SpeechAnalyzer wrapper / withTimeout)。double-resume 事故の温床 | 保守性、将来の resume クラッシュ |
| B-4 | カバレッジ 80% 判定(`lastEnd / chunkDuration`)が末尾無音を誤検知し、不要な server 再試行を誘発 | 「ローカル」設定でも Apple サーバー送信+処理時間倍増 |
| B-5 | `endBackgroundTask` / `isIdleTimerDisabled` を非 MainActor 文脈から直接呼ぶ箇所がある。複数タスク同時実行時、先に終わったタスクが `isIdleTimerDisabled = false` に戻す | strict concurrency 違反予備軍、画面ロック早期化 |

---

## 2. PR-B1: recognitionTask のキャンセル徹底(B-1)

### 2.1 変更対象
- `Memora/Core/Services/STTService.swift`(`STTBackendExecutor` 内)

### 2.2 実装

`transcribeWithSpeechRecognizer` 内、**3箇所**を修正する。

(1) タイムアウトハンドラ — `clearRecognitionTask()` → `cancelRecognitionTask()`:

```swift
let timeoutWorkItem = DispatchWorkItem(qos: .userInitiated) { [weak self] in
    callbackLock.lock()
    let shouldResume = !didResume
    didResume = true
    callbackLock.unlock()
    guard shouldResume else { return }
    STTConsoleLog("[MemoraSTT] SFSpeechRecognizer タイムアウト (\(timeoutSeconds)s) — onDevice: \(forceOnDevice)")
    DebugLogger.shared.addLog("STTBackend", "SFSpeechRecognizer タイムアウト (\(timeoutSeconds)s) — onDevice: \(forceOnDevice)", level: .warning)
    self?.cancelRecognitionTask()   // ← 変更: 参照破棄でなくキャンセル
    continuation.resume(throwing: OnDeviceTranscriptionTimeoutError())
}
```

(2) エラーコールバック — `clearRecognitionTask()` のままで可(タスクは既に終了)だが、
`shouldResume == false` の分岐(タイムアウト後に遅延エラーが届いたケース)では**何もしない前に必ず return** している現実装を維持。

(3) `deinit` 相当の保険: `STTBackendExecutor` に以下を追加(chunk ループが throw で抜けた場合のタスク残存を防ぐ):

```swift
deinit {
    cancelRecognitionTask()
}
```

`cancelRecognitionTask()` は既存実装(lock → `recognitionTask?.cancel()` → nil)をそのまま使用。

### 2.3 キャンセル後の遅延コールバック対策

`SFSpeechRecognitionTask.cancel()` 後、コールバックが `error`(canceled)で1回発火し得る。
現実装は `didResume` ガードで resume を防いでいるが、**`partialResult` はガード外**。
キャンセル/タイムアウト後の partial 発火を止めるため、コールバック先頭に追加:

```swift
let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
    timeoutWorkItem.cancel()

    // タイムアウト/キャンセル確定後のコールバックは partial を含め一切処理しない
    callbackLock.lock()
    let alreadyResumed = didResume
    callbackLock.unlock()
    if alreadyResumed { return }

    // ...以降は既存ロジック(error → final → partial の順)
}
```

注意: 既存コードは `if !result.isFinal { partialResult(...); return }` が resume ガードより前にある。上記 early-return を**関数先頭**に置くことで partial 経路も塞がる。

### 2.4 AC / 確認方法

1. 10 分以上の音声(on-device モデル未 DL 状態を再現するか、`timeoutSeconds` を一時的に 3 秒へ短縮したデバッグビルド)でタイムアウトを誘発 → `[MemoraSTT]` ログに「タイムアウト」後、同 taskId の partialResult ログが**出ない**こと。
2. Instruments (Time Profiler / Activity Monitor) でタイムアウト後に speech 関連スレッドの CPU が数秒内に沈静化。
3. 既存の正常系(短い録音のローカル文字起こし)が従来どおり完走。
4. `MemoraTests` green。08_test_plan の `timeoutCancelsRecognitionTask` テスト green。

---

## 3. PR-B2: バックグラウンド期限切れの安全停止(B-2, B-5)

### 3.1 変更対象
- `Memora/Core/Services/STTService.swift`(`STTService` 本体)

### 3.2 設計

- expiration handler で **該当 taskId の `STTTaskHandle.cancel()` を呼ぶ**。既存の cancel は `resultTask.cancel()` → chunk ループの `Task.checkCancellation()` で `CancellationError` → `.transcriptionCancelled` yield → cleanup、という経路が既に成立している(確認済み)。
- `endBackgroundTask` と `isIdleTimerDisabled` の UIKit 呼び出しを `MainActor` に寄せる。
- `isIdleTimerDisabled` はアクティブタスク数で参照カウント管理する。

### 3.3 実装

(1) アクティブ数カウント用ヘルパを `STTService` に追加:

```swift
/// isIdleTimerDisabled の参照カウント。複数タスク同時実行時に
/// 先に終わったタスクが画面ロック抑止を解除してしまう問題を防ぐ。
private var idleTimerHoldCount = 0

@MainActor
private func acquireIdleTimerHold() {
    idleTimerHoldCount += 1
    UIApplication.shared.isIdleTimerDisabled = true
}

@MainActor
private func releaseIdleTimerHold() {
    idleTimerHoldCount = max(0, idleTimerHoldCount - 1)
    if idleTimerHoldCount == 0 {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
```

注: `idleTimerHoldCount` は MainActor からのみ触るため追加ロック不要(2メソッドとも `@MainActor`)。

(2) `startTranscription` の該当箇所を差し替え:

```swift
let bgId = await MainActor.run { () -> UIBackgroundTaskIdentifier in
    self.acquireIdleTimerHold()
    return UIApplication.shared.beginBackgroundTask(
        withName: "MemoraSTT-\(handle.taskId)"
    ) { [weak self, weak handle] in
        // 猶予切れ: STT タスク自体をキャンセルし、その後 bg task を返却する。
        DebugLogger.shared.addLog("STTService", "backgroundTask 期限切れ — タスクをキャンセル: \(handle?.taskId ?? "?")", level: .warning)
        Task { [weak self, weak handle] in
            await handle?.cancel()
            await self?.endBackgroundTaskOnMain(taskId: handle?.taskId)
        }
    }
}
```

(3) 完了監視 Task 内の後始末も MainActor 経由に統一:

```swift
Task { [weak self] in
    do {
        _ = try await task.value
    } catch {
        STTConsoleLog("[MemoraSTT] バックグラウンドタスクエラー: \(error.localizedDescription)")
    }
    self?.removeTask(taskId: handle.taskId)
    await self?.endBackgroundTaskOnMain(taskId: handle.taskId)
    await MainActor.run { self?.releaseIdleTimerHold() }
}
```

(4) `endBackgroundTask(taskId:)` を MainActor 版に改名・変更:

```swift
private func endBackgroundTaskOnMain(taskId: String?) async {
    guard let taskId else { return }
    let bgId: UIBackgroundTaskIdentifier? = {
        stateLock.lock()
        defer { stateLock.unlock() }
        return backgroundTaskIdentifiers.removeValue(forKey: taskId)
    }()
    guard let bgId, bgId != .invalid else { return }
    await MainActor.run {
        UIApplication.shared.endBackgroundTask(bgId)
    }
    DebugLogger.shared.addLog("STTService", "endBackgroundTask: \(taskId)", level: .info)
}
```

既存の同期版 `endBackgroundTask(taskId:)` の呼び出し元をすべて置換すること(`grep "endBackgroundTask(taskId"`)。

### 3.4 AC / 確認方法

1. 3 分超のローカル文字起こし中にホームへ移動 → 約 30 秒後、sim log(XcodeBuildMCP `start_sim_log_cap`)に「backgroundTask 期限切れ — タスクをキャンセル」→ `.transcriptionCancelled` → Live Activity `finish(success: false)` の順で出る。
2. アプリ復帰時、FileDetail が「実行中」のまま固まらない(キャンセル/失敗状態が UI に反映。UI 側の表示改善は 04 で扱うが、少なくとも isTranscribing が解除される)。
3. 2つのファイルを連続で文字起こし開始 → 1つ目完了時点で画面が自動ロックされない(2つ目完了まで `isIdleTimerDisabled` 維持)。
4. 正常系(前面のまま完走)で従来どおり成功。

---

## 4. PR-B3: タイムアウトユーティリティ共通化(B-3)

### 4.1 変更対象
- `Memora/Core/Services/STTSupportTypes.swift`(ユーティリティ追加)
- `Memora/Core/Services/STTService.swift`(3箇所の置換)
- `MemoraTests/Services/STTDeadlineTests.swift`(新規、08 参照)

### 4.2 設計

`withCheckedThrowingContinuation` + `DispatchWorkItem` + `NSLock` の3重複を、
テスト済みの1実装に集約する。要件:

- 非協力的(cancellation を見ない)作業でも期限で必ず抜ける。
- resume は厳密に1回。期限後に完了した作業の結果は破棄。
- 期限発火時、内部 Task に `cancel()` を送る(協力的作業なら早期終了する)。
- 期限発火時に呼ぶ `onDeadline` フック(recognitionTask のキャンセル等、副作用の注入用)。

### 4.3 実装

`STTSupportTypes.swift` 末尾に追加:

```swift
// MARK: - Deadline Utility

struct DeadlineExceededError: Error, LocalizedError {
    let seconds: TimeInterval
    var errorDescription: String? { "処理が \(Int(seconds)) 秒以内に完了しませんでした" }
}

/// 非協力的な async 作業に期限を課す。
/// - resume は厳密に1回(期限後に届いた結果/エラーは破棄)。
/// - 期限発火時: operation Task に cancel を送り、onDeadline を実行してから throw する。
/// - 呼び出し側は DeadlineExceededError を捕捉して従来のエラー型へマップしてよい。
func withDeadline<T: Sendable>(
    seconds: TimeInterval,
    onDeadline: (@Sendable () -> Void)? = nil,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
        let lock = NSLock()
        var resumed = false

        @Sendable func resumeOnce(_ body: () -> Void) {
            lock.lock()
            let shouldRun = !resumed
            resumed = true
            lock.unlock()
            if shouldRun { body() }
        }

        let work = Task {
            do {
                let value = try await operation()
                resumeOnce { continuation.resume(returning: value) }
            } catch {
                resumeOnce { continuation.resume(throwing: error) }
            }
        }

        let deadlineItem = DispatchWorkItem(qos: .userInitiated) {
            resumeOnce {
                work.cancel()
                onDeadline?()
                continuation.resume(throwing: DeadlineExceededError(seconds: seconds))
            }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + seconds,
            execute: deadlineItem
        )

        // 正常完了時にタイマーを掃除する監視タスク
        Task {
            _ = await work.result
            deadlineItem.cancel()
        }
    }
}
```

置換対象(挙動互換のマッピング):

| 現行 | 置換後 |
|---|---|
| `transcribeWithSpeechAnalyzerWithTimeout`(60s、自前 continuation) | `try await withDeadline(seconds: 60) { try await self.transcribeWithSpeechAnalyzer(...) }` を呼び、`DeadlineExceededError` を catch して `OnDeviceTranscriptionTimeoutError()` に変換して rethrow(既存の呼び出し側 catch 分岐を壊さないため) |
| `withTimeout(seconds:operation:)`(diarization 用、非 throw) | `detectSpeakersWithTimeout` 内を `do { return try await withDeadline(seconds: timeout) { await self.diarizationService.detectSpeakers(...) } } catch { /* timeout ログ */ return segments }` に。`TimeoutResult` enum と旧 `withTimeout` は削除 |
| `transcribeWithSpeechRecognizer` 内の timeout | **置換しない。** SFSpeech は continuation の resume 主体が delegate コールバックであり構造が異なる。PR-B1 の修正のみ適用し、コメントで「withDeadline 非適用の理由」を残す |

### 4.4 AC

1. `STTDeadlineTests`(08 §2)の4ケース green: 即時成功 / 期限超過 / 期限後遅延完了の破棄 / onDeadline 発火。
2. SpeechAnalyzer 経路・diarization 経路の既存ログ文言(「60秒タイムアウト」「話者分離タイムアウト」)が同等に出る。
3. `TimeoutResult` / 旧 `withTimeout` がコードベースから消えている。

---

## 5. PR-B4: 末尾無音カバレッジ誤検知の抑制(B-4)

### 5.1 変更対象
- `Memora/Core/Services/STTService.swift`(`STTBackendExecutor.transcribeLocally`)
- `Memora/Core/Services/STTSupportTypes.swift`(無音測定ヘルパ追加)

### 5.2 設計

現行判定:

```
coverage = lastSegment.endSec / chunkDuration
coverage < 0.8 → server 再試行
```

改善: カバレッジ不足のとき、**未カバー区間(lastEnd〜chunk 末尾)の平均音量を測定**し、
実質無音(RMS が閾値未満)なら「カバー済み」とみなして server 再試行しない。

### 5.3 実装

ヘルパ(`STTSupportTypes.swift`):

```swift
// MARK: - Tail Silence Probe

enum AudioSilenceProbe {
    /// 指定区間の平均 RMS(0.0〜1.0 近似)を返す。読めない場合は nil。
    /// 長時間読込を避けるため最大 60 秒 / 4096 frame バッファで走査する。
    static func averageRMS(url: URL, startSec: Double, endSec: Double) -> Float? {
        guard endSec > startSec else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let sampleRate = format.sampleRate
            let clampedEnd = min(endSec, startSec + 60)
            let startFrame = AVAudioFramePosition(startSec * sampleRate)
            let frameCount = AVAudioFrameCount((clampedEnd - startSec) * sampleRate)
            guard frameCount > 0, startFrame < file.length else { return nil }
            file.framePosition = min(startFrame, file.length - 1)

            var sumSquares: Double = 0
            var totalFrames: Double = 0
            let bufferSize: AVAudioFrameCount = 4096
            var remaining = min(frameCount, AVAudioFrameCount(file.length - file.framePosition))

            while remaining > 0 {
                let thisRead = min(bufferSize, remaining)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: thisRead) else { return nil }
                try file.read(into: buffer, frameCount: thisRead)
                guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { break }
                for i in 0..<Int(buffer.frameLength) {
                    let v = Double(channel[i])
                    sumSquares += v * v
                }
                totalFrames += Double(buffer.frameLength)
                remaining -= buffer.frameLength
            }
            guard totalFrames > 0 else { return nil }
            return Float((sumSquares / totalFrames).squareRoot())
        } catch {
            return nil
        }
    }
}
```

判定側(`transcribeLocally` の coverage ブロックを差し替え):

```swift
let chunkDuration = await audioFileDuration(for: audioURL)
let lastEnd = transcription.segments.last?.endSec ?? 0
let coverage = chunkDuration > 1.0 ? lastEnd / chunkDuration : 1.0
if coverage < 0.8 {
    // 未カバー区間が実質無音なら、早期 isFinal は正当 → server 再試行しない
    let tailRMS = AudioSilenceProbe.averageRMS(url: audioURL, startSec: lastEnd, endSec: chunkDuration)
    let silenceThreshold: Float = 0.008   // ■確認せよ: 実録音サンプルで調整(会話 RMS 目安 0.02〜0.2)
    if let tailRMS, tailRMS < silenceThreshold {
        DebugLogger.shared.addLog(
            "STTBackend",
            "低カバレッジ (\(String(format: "%.0f", coverage * 100))%) だが末尾は無音 (RMS=\(String(format: "%.4f", tailRMS))) — server 再試行をスキップ",
            level: .info
        )
    } else {
        DebugLogger.shared.addLog(
            "STTBackend",
            "低カバレッジ (\(String(format: "%.0f", coverage * 100))%) — server でリトライ (tailRMS=\(tailRMS.map { String(format: "%.4f", $0) } ?? "n/a"))",
            level: .warning
        )
        throw OnDeviceTranscriptionTimeoutError()
    }
}
```

診断強化: この分岐の結果(skip / retry と RMS 値)を `STTBackendDiagnosticEntry.fallbackReason` 相当に載せる場合、entry の**新規フィールド追加は 07 の schema 作業と衝突しない**(Codable 構造体でありログのみ)。`fallbackReason` 文字列に含める方式で可。

### 5.4 AC

1. 「30 秒発話 + 60 秒無音」の合成 WAV(`scripts` 等で生成、または実録音)で: server 再試行が**発生しない**ログ。
2. 「実際に途中で認識が打ち切られた音声」(on-device 早期 isFinal を再現できる長尺・低品質音声)で: 従来どおり server 再試行が発生。再現不能な場合はユニットテストで判定ロジックのみ検証(08 §3)。
3. 通常の会話録音で挙動変化なし。

---

## 6. 回帰確認(PR-B1〜B4 共通)

- [ ] 90 秒未満(単一チャンク)/ 90 秒超(複数チャンク)/ 3 時間超の各ローカル文字起こしが完走
- [ ] API モード(OpenAI キー設定)での並列チャンク文字起こしが完走
- [ ] 文字起こし中キャンセル(FileDetail からの中断操作があれば)で `.transcriptionCancelled` → 一時チャンク削除
- [ ] SpeechAnalyzer flag ON(iOS 26 実機、任意)で preflight → 実行 → 失敗時 SFSpeech フォールバックのログ順
- [ ] Live Activity の開始/更新/終了
- [ ] STTDiagnosticsView に backend / fallbackReason / 処理時間が記録される
