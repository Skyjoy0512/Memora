# 06. 「後から話者分離を実行」opt-in 機能 詳細設計書

Lane: B (STT コア・最小公開 API 追加) + A (UI) / **STT コアタスク(公開 API 追加のみ、選択順・クラスタリングロジック変更なし)**
依存: 02(withDeadline)/ 対応 PR: PR-B7(コア)→ PR-A9(UI)

---

## 1. 目的と背景

現状(確認済み): 話者分離は「API モード かつ `speakerDiarizationEnabled` 設定 ON」のときだけ文字起こしパイプライン内で実行され、**ローカルモードでは常にラベルが空文字で保存される**(`removingSpeakerLabels`)。ローカル派ユーザーが話者ラベルを得る手段がない。

PLAUD は話者ラベル付き transcript が標準。フルパリティ(常時自動)は電池・処理時間の観点で North Star の「ローカルは速く」方針と衝突するため、**文字起こし済みファイルに対する opt-in 後処理**として提供する。

boundary doc の Omi 導入順序(1. 話者分離の安定化 → 2. サンプル抽出 → …)にも整合する(本件は 1 の範囲)。

## 2. スコープ境界

- やる: 保存済み transcript のセグメントに対し、既存 `diarizationService.detectSpeakers` を全体ファイルで実行し、結果ラベルを `Transcript` に上書き保存する。進捗 UI。キャンセル。
- やらない: クラスタリングアルゴリズム変更 / 話者登録・埋め込み(boundary の 2〜5)/ 保存形式変更(並列配列のまま更新)/ 自動実行。

## 3. PR-B7: コア公開 API(`STTService` への最小追加)

### 3.1 変更対象
- `Memora/Core/Services/STTService.swift`

### 3.2 実装

既存 private `detectSpeakersWithTimeout` を包む公開メソッドを追加する。**選択順・既存パイプラインは不変**:

```swift
// MARK: - Post-hoc Speaker Diarization (opt-in)

/// 保存済み transcript のセグメントに対する後付け話者分離。
/// 文字起こしパイプラインとは独立に呼び出せる。
/// - Returns: 話者ラベルを付与したセグメント。タイムアウト/失敗時は入力をそのまま返す。
func detectSpeakersPostHoc(
    audioURL: URL,
    segments: [TranscriptionSegment],
    numSpeakers: Int? = nil,
    timeout: TimeInterval = 300
) async -> [TranscriptionSegment] {
    guard FileManager.default.fileExists(atPath: audioURL.path), !segments.isEmpty else {
        return segments
    }
    DebugLogger.shared.addLog("STTService", "後付け話者分離 開始 — \(segments.count)セグメント", level: .info)
    return await detectSpeakersWithTimeout(
        audioURL: audioURL,
        segments: segments,
        numSpeakers: numSpeakers,
        timeout: timeout
    )
}
```

`TranscriptionEngine`(facade)にブリッジを追加(VM から呼びやすくするため):

```swift
// TranscriptionEngine.swift
func detectSpeakersPostHoc(
    audioURL: URL,
    segments: [TranscriptionSegment],
    numSpeakers: Int?
) async -> [TranscriptionSegment] {
    await (sttService as? STTService)?.detectSpeakersPostHoc(
        audioURL: audioURL,
        segments: segments,
        numSpeakers: numSpeakers
    ) ?? segments
}
```

進捗: 既存 `detectSpeakers` は進捗コールバックを持たない(確認済み、`SpeakerDiarizationProtocol` は `detectSpeakers(audioURL:segments:numSpeakers:)` のみ)。**プロトコル変更はしない**。UI 進捗は「不確定(indeterminate)+経過秒数表示」とする(§4)。

### 3.3 PR-B7 の STT 報告事項(PR 説明に記載)

- バックエンド選択順への影響: なし(パイプライン外の追加 API)。
- SpeechAnalyzer / SFSpeechRecognizer / API への影響: なし。
- 話者分離への影響: 既存 `detectSpeakersWithTimeout` の再利用のみ。ロジック不変。
- 保存フォーマットへの影響: なし(保存は UI 層 PR-A9 が既存 `Transcript` の並列配列を上書き)。

## 4. PR-A9: UI(FileDetail からの実行と保存)

### 4.1 変更対象
- `Memora/Core/ViewModels/FileDetailViewModel.swift`
- `Memora/Views/FileDetail/TranscriptTab.swift`

### 4.2 VM 実装

```swift
// FileDetailViewModel に追加
var isDiarizing = false
var diarizationElapsedSec = 0
private var diarizationTask: Task<Void, Never>?

/// 保存済み transcript に後付けで話者分離を実行し、結果を保存し直す。
func runPostHocDiarization() {
    guard !isDiarizing else { return }
    guard let url = audioURL else {
        errorMessage = "音声URLがありません"
        showErrorAlert = true
        return
    }
    guard let result = transcriptResult, !result.segments.isEmpty else {
        errorMessage = "先に文字起こしを実行してください"
        showErrorAlert = true
        return
    }

    isDiarizing = true
    diarizationElapsedSec = 0

    // 経過秒カウンタ
    let ticker = Task { @MainActor [weak self] in
        while !(Task.isCancelled) {
            try? await Task.sleep(for: .seconds(1))
            self?.diarizationElapsedSec += 1
        }
    }

    diarizationTask = Task { @MainActor [weak self] in
        guard let self else { return }
        defer {
            ticker.cancel()
            self.isDiarizing = false
        }

        // UI 型 → コア型へ変換
        let coreSegments = result.segments.enumerated().map { index, seg in
            TranscriptionSegment(
                id: "segment-\(index)",
                speakerLabel: seg.speakerLabel,
                startSec: seg.startTime,
                endSec: seg.endTime,
                text: seg.text
            )
        }

        let labeled = await self.transcriptionEngine.detectSpeakersPostHoc(
            audioURL: url,
            segments: coreSegments,
            numSpeakers: self.audioFile.referenceSpeakerCount
        )
        // ■確認: FileDetailViewModel が transcriptionEngine を直接保持しているか。
        // 保持していなければ pipelineCoordinator 経由のブリッジを1メソッド追加する
        // (Coordinator は @MainActor で transcriptionEngine を保持している)。

        guard !Task.isCancelled else { return }

        let distinctSpeakers = Set(labeled.map(\.speakerLabel).filter { !$0.isEmpty })
        guard distinctSpeakers.count >= 1 else {
            self.errorMessage = "話者を検出できませんでした。もう一度お試しください。"
            self.showErrorAlert = true
            return
        }

        self.persistDiarizedSegments(labeled)
        self.loadSavedTranscript()   // 既存の再読込で transcriptResult を更新
        self.successMessage = "話者分離が完了しました(\(distinctSpeakers.count) 人を検出)"
        self.showSuccessAlert = true
    }
}

func cancelPostHocDiarization() {
    diarizationTask?.cancel()
    diarizationTask = nil
    isDiarizing = false
}

/// Transcript(並列配列)へラベルのみ上書き保存。保存形式は変更しない。
private func persistDiarizedSegments(_ labeled: [TranscriptionSegment]) {
    let targetID = audioFile.id
    var descriptor = FetchDescriptor<Transcript>(
        predicate: #Predicate { $0.audioFileID == targetID }
    )
    descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
    descriptor.fetchLimit = 1
    guard let transcript = try? modelContext.fetch(descriptor).first else { return }

    // セグメント数が一致する場合のみラベル上書き(安全側)。
    // 不一致(編集等で変わった)なら全配列を作り直す。
    if transcript.segmentTexts.count == labeled.count {
        transcript.speakerLabels = labeled.map(\.speakerLabel)
    } else {
        transcript.speakerLabels = labeled.map(\.speakerLabel)
        transcript.segmentStartTimes = labeled.map(\.startSec)
        transcript.segmentEndTimes = labeled.map(\.endSec)
        transcript.segmentTexts = labeled.map(\.text)
    }
    do {
        try modelContext.save()
    } catch {
        errorMessage = "話者ラベルの保存に失敗しました: \(error.localizedDescription)"
        showErrorAlert = true
    }
}
```

注意(キャンセルの意味論): `detectSpeakersPostHoc` 内部の diarization は非協力的な可能性がある(02 §4 参照)。`cancelPostHocDiarization` は **UI 状態の解除**であり、裏の計算は timeout(300s)まで走り得る。結果が返っても `Task.isCancelled` ガードで保存しない。この制約を UI 文言に反映(§4.3)。

### 4.3 TranscriptTab 実装

transcript 表示済み・話者ラベルが単一/空のときにカードを出す(既存 `speakerRegistrationCard` の直前に配置):

```swift
@ViewBuilder
private var postHocDiarizationCard: some View {
    if let result = vm.transcriptResult, !result.segments.isEmpty {
        let speakerCount = Set(result.segments.map(\.speakerLabel).filter { !$0.isEmpty }).count
        if speakerCount <= 1 {
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                    Label("話者を分離", systemImage: "person.2.wave.2")
                        .font(MemoraTypography.headline)

                    if vm.isDiarizing {
                        HStack(spacing: MemoraSpacing.sm) {
                            ProgressView()
                            Text("話者を解析中… \(vm.diarizationElapsedSec)秒")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                            Button("中止") { vm.cancelPostHocDiarization() }
                                .font(MemoraTypography.caption1)
                        }
                        Text("録音の長さによっては数分かかります。この画面を開いたままお待ちください。")
                            .font(MemoraTypography.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("この文字起こしにはまだ話者ラベルがありません。音声を解析して「Speaker 1 / Speaker 2 …」のラベルを付けられます。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                        Button {
                            vm.runPostHocDiarization()
                        } label: {
                            Text("話者分離を実行")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}
```

body 内の配置: `speakerRegistrationCard` の直前に `postHocDiarizationCard` を追加。

### 4.4 AC

1. ローカルモードで文字起こしした 2 人会話(5〜10 分)で「話者分離を実行」→ 完了アラート → セグメントに Speaker 1/2 ラベルが表示され、**アプリ再起動後も保存されている**。
2. `referenceSpeakerCount`(Plaud import 由来)があるファイルでは numSpeakers ヒントが渡る(DebugLogger の「numSpeakers: n」ログで確認)。
3. 実行中に FileDetail を離れて戻っても UI が破綻しない(■確認: VM は画面ごとに再生成されるため、離脱で ticker/task が破棄される。`onDisappear` の `cleanup()` に `cancelPostHocDiarization()` を追加すること)。
4. 中止 → UI 即解除、結果は保存されない。
5. 既に複数話者ラベルがある transcript ではカードが出ない。
6. 文字起こしパイプライン(通常フロー)の挙動・処理時間に変化なし。

## 5. PR 分割

| PR | 内容 |
|---|---|
| PR-B7 | `detectSpeakersPostHoc` 公開 + facade ブリッジ(コアのみ、UI 変更なし) |
| PR-A9 | VM + TranscriptTab(コア変更なし) |
