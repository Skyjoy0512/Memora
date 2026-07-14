# 03. Transcript ↔ Audio 同期(実タイムスタンプ)詳細設計書

Lane: B (STT コア) + A (UI 小変更) / **STT コアタスク**
依存: 02 実装後を推奨(同ファイルのコンフリクト回避) / 対応 PR: PR-B5, PR-B6, PR-A5

---

## 1. 目的と背景

PLAUD Note の中核体験は「transcript の任意箇所 ↔ 音声該当位置」の相互参照。Memora は UI 側の骨格(セグメントタップ→ `vm.seekToTime(segment.startTime)`、再生位置ハイライト `currentPlaybackTime` 判定)を **既に実装済み**(`TranscriptTab.swift` / `TranscriptView.swift` で確認済み)。

問題はデータ側にある(確認済み):

- **SpeechAnalyzer 経路**: `SpeechAnalyzerService26.transcribe` が全文 String のみ返し、`makeFallbackSegments` が「改行分割 + 音声全長を行数で等分」した**架空のタイムスタンプ**を生成。
- **API 経路**: `AIService.transcribe`(OpenAI `gpt-4o-transcribe` ほか)も String のみ返し、同じく捏造セグメント。
- **SFSpeechRecognizer 経路のみ実測**(`segment.timestamp` / `duration` を使用)。

結果: SpeechAnalyzer/API で作った transcript は、タップシークも SRT/VTT export も実際の音声位置とズレる。

## 2. 設計方針

1. backend が**実測タイミングを返せる場合は必ずそれを使う**。`makeFallbackSegments` は「タイミングを一切得られなかった場合の最終フォールバック」に格下げし、生成したセグメントに **`isEstimatedTiming` フラグ**を立てる。
2. 実測タイミングの取得方法:
   - **API 経路(PR-B5)**: OpenAI transcription API を verbose(segment timestamps 付き)で叩く。`gpt-4o-transcribe` は `response_format=json` のみ対応でセグメントを返さないため、**タイムスタンプが必要な文字起こしは `whisper-1` + `response_format=verbose_json` を使う**。■確認せよ: 実装時点の OpenAI docs で `gpt-4o-transcribe` 系の `timestamp_granularities` 対応状況。対応済みならモデル据え置きで verbose 化してよい(その場合も下記 DTO は共通)。
   - **SpeechAnalyzer 経路(PR-B6)**: `SpeechTranscriber.results` の各 result が持つタイミング情報(`AttributedString` の `audioTimeRange` 属性 / result の CMTimeRange)からセグメントを構築。■確認せよ(iOS 26 実機): result 単位で `range`(CMTimeRange)が取れるか。取れない場合は volatile/final 境界時刻での近似にフォールバックし、それも不可なら従来 fallback + `isEstimatedTiming`。
3. **UI は推定タイミングを区別表示**: `isEstimatedTiming == true` のセグメントはタイムスタンプをグレー斜体+「推定」表示にし、SRT/VTT export 時に警告を出す(export 自体は許可)。
4. 保存形式(`Transcript` 並列配列)は**変更しない**(07 のスコープ)。`isEstimatedTiming` は Transcript には保存せず、当面「セグメント数==1 かつ等間隔」等での再推定はしない — 代わりに transcript 保存時に `speakerLabels` と同様の第5配列を追加**しない**こと。フラグの永続化は 07 の schema 移行に相乗りする。それまで UI 表示は `TranscriptResult` 経由(セッション内)+「fallback 生成だったか」を `STTBackendDiagnosticEntry` から復元しない簡易運用とする(§6 AC 参照)。

## 3. DTO 変更(コア契約)

`TranscriptionSegment`(`CoreDTOs.swift`)にフラグを追加。**既存 init 互換を保つ**:

```swift
struct TranscriptionSegment: Sendable {   // 既存宣言に合わせる(■確認: 既存の準拠プロトコル)
    let id: String
    let speakerLabel: String
    let startSec: Double
    let endSec: Double
    let text: String
    /// タイミングが実測でなく推定(等分割フォールバック)であることを示す。
    let isEstimatedTiming: Bool

    init(
        id: String,
        speakerLabel: String,
        startSec: Double,
        endSec: Double,
        text: String,
        isEstimatedTiming: Bool = false
    ) { ... }
}
```

- デフォルト値 `false` により既存の全生成箇所は無変更でコンパイル可能。
- `SpeakerSegment`(UI 向け、`STTSupportTypes.swift`)にも同名プロパティを追加し、`TranscriptResult.init(coreResult:duration:)` のマッピングで引き継ぐ。
- `makeFallbackSegments` は `isEstimatedTiming: true` を付けて生成するよう変更。

## 4. PR-B5: API 経路の実測セグメント

### 4.1 変更対象
- `Memora/Core/Networking/AIService.swift`
- `Memora/Core/Services/STTService.swift`(`transcribeRemotely`)

### 4.2 設計

`LocalTranscriptionService` 相当の String 返却 API とは別に、**タイムド結果**を返す経路を追加する。既存の `transcribe(audioURL:) -> String` の呼び出し元(要約プレビュー等)を壊さないため、新メソッドを増やす:

```swift
// AIService 内(OpenAI 実装クラス)
struct TimedTranscription: Sendable {
    struct Segment: Sendable {
        let startSec: Double
        let endSec: Double
        let text: String
    }
    let fullText: String
    let language: String?
    let segments: [Segment]   // 空 = タイミング取得不可
}

func transcribeWithTimestamps(audioURL: URL) async throws -> TimedTranscription
```

OpenAI 実装(multipart 構築は既存 `transcribe` の boundary 処理を流用):

- `model = "whisper-1"`(または ■確認 の結果 gpt-4o 系 verbose 対応ならそのモデル)
- `response_format = "verbose_json"`
- レスポンス decode:

```swift
private struct VerboseTranscriptionResponse: Decodable {
    struct Segment: Decodable {
        let start: Double
        let end: Double
        let text: String
    }
    let text: String
    let language: String?
    let segments: [Segment]?
}
```

- 他 provider(Gemini / DeepSeek 等、■確認: 現状 API 文字起こし対応 provider を `AIService` の分岐で確認)は当面 `TimedTranscription(fullText: text, language: nil, segments: [])` を返す薄い実装で可(フォールバック経路に落ちる)。

`STTService.transcribeRemotely` の差し替え:

```swift
progress(0.2)
let timed = try await service.transcribeWithTimestamps(audioURL: audioURL)
progress(0.92)

let duration = await audioFileDuration(for: audioURL)
let baseSegments: [TranscriptionSegment]
if timed.segments.isEmpty {
    baseSegments = makeFallbackSegments(from: timed.fullText, duration: duration)  // isEstimatedTiming: true
} else {
    baseSegments = timed.segments.enumerated().map { index, seg in
        TranscriptionSegment(
            id: "segment-\(index)",
            speakerLabel: "Speaker 1",
            startSec: seg.startSec,
            endSec: min(seg.endSec, duration > 0 ? duration : seg.endSec),
            text: seg.text.trimmingCharacters(in: .whitespacesAndNewlines),
            isEstimatedTiming: false
        )
    }
}
```

チャンク分割との整合: チャンクは 90 秒単位でオフセット加算マージされる(既存 `merge`)。verbose_json の start/end は**チャンク先頭基準**なので既存マージのオフセット加算がそのまま正しい。変更不要。

### 4.3 AC

1. API モードで 2〜3 分の音声を文字起こし → SRT export → 動画プレイヤー(VLC 等)で音声と字幕が ±1 秒以内に一致。
2. `whisper-1` へ切り替えたことで全文品質が劣化していないか、同一音声で `gpt-4o-transcribe`(旧)と比較し PR に所見を記載。明確に劣化する場合は「全文は gpt-4o、セグメントは whisper-1 verbose の2回呼び」案を検討事項として Issue 化(実装しない)。
3. 非対応 provider では従来同様に動作(推定セグメント+後述の UI 表示)。
4. STT コア報告テンプレートに従い、影響範囲を PR に明記。

## 5. PR-B6: SpeechAnalyzer 経路のタイムド結果

### 5.1 変更対象
- `Memora/Core/Networking/AIService.swift`(`SpeechAnalyzerService26`)
- `Memora/Core/Services/STTService.swift`(`transcribeWithSpeechAnalyzer`)

### 5.2 設計・実装

`SpeechAnalyzerService26` に新メソッドを追加(既存 `transcribe` は残す):

```swift
@available(iOS 26.0, *)
struct AnalyzerTimedResult: Sendable {
    let text: String
    let segments: [(startSec: Double, endSec: Double, text: String)]
}

@available(iOS 26.0, *)
func transcribeTimed(audioURL: URL) async throws -> AnalyzerTimedResult
```

実装方針(`transcribe` の result ループを拡張):

```swift
var segments: [(Double, Double, String)] = []
for try await result in transcriber.results {
    guard result.isFinal else { continue }   // ■確認: 既存ループの final 判定方法に合わせる
    let text = String(result.text.characters)
    // ■確認せよ(iOS 26 実機・最優先検証事項):
    // 1) result に CMTimeRange(range / audioTimeRange)があるか
    // 2) なければ result.text(AttributedString)の run に
    //    \.audioTimeRange 属性があるか(WWDC25 SpeechAnalyzer セッション参照)
    if let range = result.range {   // 仮: CMTimeRange が取れる場合
        segments.append((range.start.seconds, range.end.seconds, text))
    } else {
        segments.append((-1, -1, text))   // タイミング不明マーカー
    }
}
```

- 1つでも `-1` マーカーが混ざったら全体を「タイミング取得不可」として `segments: []` で返す(部分的に正しいタイムスタンプは混乱の元)。
- `STTService.transcribeWithSpeechAnalyzer` は PR-B5 と同型の分岐(実測→そのまま / 空→fallback+推定フラグ)。

### 5.3 検証タスク(実装 PR より前に実施し、結果を PR 説明に貼る)

iOS 26 実機で 60 秒サンプルを流し、以下をログ出力して確認:
- `result` の型に含まれるプロパティ一覧(`Mirror(reflecting:)` で dump)
- `AttributedString` run の属性キー一覧
取得可否によって §5.2 の分岐(実測 or 全 fallback)を確定する。**取得不可でも PR-B6 は「fallback に isEstimatedTiming を立てる」変更として成立させる**(UI 側の推定表示が機能するため)。

### 5.4 AC

1. (タイミング取得可の場合)iOS 26 実機で SpeechAnalyzer 文字起こし → セグメントタップで正しい位置へシーク。
2. (取得不可の場合)生成セグメントすべてに `isEstimatedTiming == true` が立つ。
3. SpeechAnalyzer flag OFF の既定挙動に影響なし。

## 6. PR-A5: UI — 推定タイミング表示と自動スクロール

### 6.1 変更対象(UI のみ、コア禁止)
- `Memora/Views/TranscriptView.swift`(`SpeakerSegmentView`, `TranscriptContentView`)
- `Memora/Views/FileDetail/TranscriptTab.swift`
- `Memora/Views/ExportOptionsSheet.swift`(警告文言)

### 6.2 実装

(1) `SpeakerSegmentView` のタイムスタンプ表示:

```swift
HStack(spacing: 4) {
    if segment.isEstimatedTiming {
        Text("約 \(formatTime(segment.startTime))")
            .italic()
            .foregroundStyle(MemoraColor.textTertiary)
    } else {
        Text(formatTime(segment.startTime))
            .foregroundStyle(Color(hex: "58585A"))
    }
}
.font(.system(size: 11))
```

(2) 再生追従の自動スクロール(`TranscriptTab` 側。`TranscriptContentView` を `ScrollViewReader` 対応に):

```swift
// TranscriptContentView 内: 各 SpeakerSegmentView に .id(index) を付与
// TranscriptTab 側(親 ScrollView は FileDetailView が持つため、ここでは
// onChange で anchor スクロールを依頼する):
```

■確認せよ: FileDetail の ScrollView は `FileDetailView.mainContent` にある(タブ横断の単一 ScrollView)。`ScrollViewReader` はその ScrollView を包む必要があるため、実装は次のいずれか:
- 案 a(推奨): `FileDetailView` の `ScrollView { ... }` を `ScrollViewReader { proxy in ScrollView { ... } }` で包み、proxy を environment で `TranscriptTab` に渡す。
- 案 b: iOS 17 の `scrollPosition(id:)` を使い、再生中セグメント index を `@Binding` で親へ伝える。

再生中判定は既存の `isPlaying`(`currentPlaybackTime >= startTime && < endTime`)を流用し、再生中セグメントが変わったタイミングで:

```swift
.onChange(of: currentPlayingIndex) { _, newIndex in
    guard vm.isPlaying, let newIndex else { return }
    withAnimation(.easeInOut(duration: 0.25)) {
        proxy.scrollTo(newIndex, anchor: .center)
    }
}
```

ユーザーが手でスクロール中は追従を止める: `simultaneousGesture(DragGesture().onChanged { autoFollow = false })` +「現在位置へ」ピルボタン(タップで `autoFollow = true` + 即スクロール)。ピルは再生中かつ `autoFollow == false` のときのみ右下に表示。

(3) Export 警告: SRT/VTT 選択時、対象 transcript のセグメントに推定タイミングが含まれる場合(当面の判定: `TranscriptResult.segments.contains(where: \.isEstimatedTiming)`。保存済みデータには当該情報がないため、**セッション内で生成した結果に対してのみ警告**):

```
「この文字起こしのタイムスタンプは推定値です。SRT/VTT の時刻は実際の音声とずれる可能性があります。」
```

### 6.3 AC

1. SFSpeechRecognizer で作った transcript: 通常表示、タップシーク正確、再生で自動追従スクロール。
2. fallback で作った transcript(セッション内): 「約 mm:ss」斜体表示。
3. 手スクロール → 追従停止 → 「現在位置へ」ピル → 追従再開。
4. reduceMotion 時は `withAnimation` を抑制(`reduceMotion ? nil : ...`)。

## 7. PR 分割まとめ

| PR | Lane | 内容 |
|---|---|---|
| PR-B5 | B | API verbose セグメント + DTO フラグ + fallback 格下げ |
| PR-B6 | B | SpeechAnalyzer タイムド結果(実機検証結果に応じ2形態) |
| PR-A5 | A | 推定表示 / 自動スクロール / export 警告 |

DTO 変更(`isEstimatedTiming`)は PR-B5 に含める(最初にマージされる STT PR のため)。
