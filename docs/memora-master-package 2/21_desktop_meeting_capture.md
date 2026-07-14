# 21. デスクトップ 会議音声キャプチャ 技術設計

対象: macOS アプリ / 依存: 20

---

## 1. 課題

Zoom / Google Meet / Teams の**相手の音声**は、そのアプリがスピーカーへ出力している「システム音声」。これを録音するには OS のシステム音声取り込みが必要。macOS には歴史的に標準 API がなく Soundflower / BlackHole 等の仮想オーディオデバイスが使われてきたが、**macOS 13+ の ScreenCaptureKit で公式・高品質にアプリ音声を取得できる**ようになった。

## 2. 方式選定

| 方式 | 内容 | 評価 |
|---|---|---|
| **ScreenCaptureKit(推奨)** | macOS 13+ 公式。特定アプリ or システム全体の音声を取得。画面キャプチャ不要で音声のみ可 | ◎ 公式・安定・高音質・許可制で合法 |
| 仮想オーディオデバイス(BlackHole) | ユーザーがドライバ導入し出力をループバック | △ 導入が煩雑、配布に不向き |
| Core Audio Taps(macOS 14.4+) | `AudioHardwareCreateProcessTap` でプロセス音声を tap | ○ 新しめ、SCK と併用可 |

**ScreenCaptureKit を主軸**、必要に応じて Core Audio Process Tap(macOS 14.4+)を併用。

## 3. ScreenCaptureKit による音声キャプチャ

### 3.1 音声のみキャプチャの構成

```swift
import ScreenCaptureKit
import AVFoundation

/// システム音声(会議アプリの出力)をキャプチャする。
@available(macOS 13.0, *)
final class SystemAudioCapturer: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private let audioSink: (AVAudioPCMBuffer) -> Void

    init(audioSink: @escaping (AVAudioPCMBuffer) -> Void) {
        self.audioSink = audioSink
    }

    func start(excludingApp bundleID: String? = nil) async throws {
        // 共有可能なコンテンツを取得
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else { throw CaptureError.noDisplay }

        // 音声のみが目的なので、フィルタはディスプレイ全体(音声はシステム全体を拾う)
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true                 // ← 音声キャプチャ有効化
        config.excludesCurrentProcessAudio = true   // 自アプリの音は除外
        config.sampleRate = 48000
        config.channelCount = 2
        // 画面フレームは最小に(音声だけ欲しい)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio,
                                   sampleHandlerQueue: DispatchQueue(label: "audio.capture"))
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    // SCStreamOutput: 音声サンプル受信
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .audio,
              let pcm = sampleBuffer.toPCMBuffer() else { return }
        audioSink(pcm)
    }
}
```

■確認せよ: `capturesAudio` / `excludesCurrentProcessAudio` は macOS バージョンで API 名/可用性が変わる。macOS 13.0 での音声キャプチャ可否と、14.0+ での改善(`SCStreamConfiguration` の音声プロパティ)を実装時に確認。音声のみ用途では画面サイズを極小にして CPU を節約。

### 3.2 マイク入力との合成

会議録音は「相手(システム音声)+ 自分(マイク)」の両方が要る。

```swift
/// システム音声 + マイクをミックスして1つの録音にする。
final class MeetingRecorder {
    private let systemCapturer: SystemAudioCapturer
    private let micEngine = AVAudioEngine()
    private var mixer = AVAudioMixerNode()
    private var outputFile: AVAudioFile?

    func startRecording(to url: URL) async throws {
        // マイク入力タップ
        let input = micEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        outputFile = try AVAudioFile(forWriting: url, settings: format.settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.outputFile?.write(from: buffer)   // マイク
        }
        try micEngine.start()

        // システム音声(相手側)も同じファイルへミックス
        try await systemCapturer.start()
        // systemCapturer の audioSink で受けた PCM を outputFile にミックス書き込み
    }
}
```

■確認せよ: 2ソースのサンプルレート・フォーマットが異なる場合の変換(`AVAudioConverter`)とミックスのタイミング整合。厳密なミックスは `AVAudioEngine` に SCK の音声を流し込む形(手動ミックスバッファ)にするのが堅実。実装難度が高い部分なので、**Phase D2 前半は「システム音声のみ録音」→ 後半で「マイク合成」**に分ける。

### 3.3 話者分離への含み
会議録音では「相手」と「自分」でチャンネルを分けられる(システム音声=L、マイク=R のステレオ保存)と、後段の話者分離が楽になる。将来的に活用。

## 4. 会議アプリ検出(任意の便利機能)

Zoom/Meet/Teams が起動・通話中かを検出し「会議を録音しますか?」を提案:

```swift
// 実行中アプリの bundleID を監視
NSWorkspace.shared.runningApplications
    .contains { ["us.zoom.xos", "com.google.Chrome", "com.microsoft.teams2"].contains($0.bundleIdentifier) }
```

Meet はブラウザ内なのでアプリ検出だけでは通話中か判断できない。**過剰検出を避け、当面は手動で録音開始**を基本とし、検出は補助提案に留める。

## 5. 録音同意・法令対応(必須)

- 録音開始前に「相手の同意を得ましたか?」の確認ダイアログを出す(地域により全当事者同意が必要)。
- 録音中はメニューバーに明示的なインジケータを常時表示。
- Zoom 等の利用規約で自動録画が制限される場合があるため、ユーザー操作による録音を基本とする。

## 6. AC

1. Zoom 通話中に録音開始 → 相手の音声がキャプチャされ WAV/M4A 保存。
2. マイク合成 ON で自分の声も録音される。
3. 録音停止 → `AudioFile` 作成 → 文字起こし(22)へ。
4. 録音中インジケータ表示、開始前に同意確認。
5. 自アプリの通知音等が録音に混入しない(`excludesCurrentProcessAudio`)。

## 7. フェーズ
- D2a: システム音声のみ録音(ScreenCaptureKit)
- D2b: マイク合成、ステレオ分離保存
- D2c: 会議アプリ検出の補助提案
