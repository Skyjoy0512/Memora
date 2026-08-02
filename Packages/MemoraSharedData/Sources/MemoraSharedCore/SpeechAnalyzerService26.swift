import AVFoundation
import Foundation
@preconcurrency import Speech

public protocol LocalTranscriptionService {
    var isTranscribing: Bool { get }
    var progress: Double { get }

    func transcribe(audioURL: URL) async throws -> String
}

public enum LocalTranscriptionError: LocalizedError {
    case notSupported
    case transcriptionFailed(Error)
    case localeNotSupported
    case permissionDenied
    case assetInstallationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "ローカル文字起こしはサポートされていません"
        case .transcriptionFailed(let error):
            return "文字起こしに失敗しました: \(error.localizedDescription)"
        case .localeNotSupported:
            return "この言語はサポートされていません"
        case .permissionDenied:
            return "音声認識の権限が許可されていません"
        case .assetInstallationFailed(let message):
            return "SpeechAnalyzer 用モデルの準備に失敗しました: \(message)"
        }
    }
}

private struct SilentSTTConsoleLogger: STTConsoleLogging {
    func logDetailed(_ message: @autoclosure () -> String) {}
}

/// iOS 26.0+ SpeechAnalyzer API implementation shared by SwiftUI and RN hosts.
///
/// State remains readable through `isTranscribing` and `progress`. Hosts that
/// need Combine observation can bridge these values in a host-side wrapper.
@available(iOS 26.0, macOS 26.0, *)
public final class SpeechAnalyzerService26: LocalTranscriptionService, SpeechAnalyzerTranscribing {
    public private(set) var isTranscribing = false
    public private(set) var progress = 0.0

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private let locale: Locale
    private let consoleLogger: any STTConsoleLogging

    public init(
        locale: Locale = Locale(identifier: "ja_JP"),
        consoleLogger: (any STTConsoleLogging)? = nil
    ) {
        self.locale = locale
        self.consoleLogger = consoleLogger ?? SilentSTTConsoleLogger()
    }

    private func setup() async throws {
        let installedLocales = await SpeechTranscriber.installedLocales
        consoleLogger.logDetailed("インストール済みロケール: \(installedLocales)")

        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            consoleLogger.logDetailed("ロケール \(locale.identifier) が利用可能ではありません")
            throw LocalTranscriptionError.localeNotSupported
        }

        // offlineTranscription: ファイル一括処理用（公式推奨）
        let createdTranscriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .transcription
        )
        try await ensureAssetsInstalled(for: createdTranscriber, locale: supportedLocale)
        transcriber = createdTranscriber
        consoleLogger.logDetailed("使用ロケール: \(supportedLocale)")

        let options = SpeechAnalyzer.Options(
            priority: .userInitiated,
            modelRetention: .whileInUse
        )
        analyzer = SpeechAnalyzer(modules: [createdTranscriber], options: options)

        // 事前準備: 互換フォーマットを取得し prepareToAnalyze を呼ぶ
        let bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [createdTranscriber])
        if let bestFormat {
            consoleLogger.logDetailed("[MemoraSTT] bestAvailableAudioFormat: \(bestFormat)")
            try await analyzer?.prepareToAnalyze(in: bestFormat)
        } else {
            consoleLogger.logDetailed("[MemoraSTT] bestAvailableAudioFormat returned nil")
        }
    }

    private func ensureAssetsInstalled(
        for transcriber: SpeechTranscriber,
        locale: Locale
    ) async throws {
        let initialStatus = await AssetInventory.status(forModules: [transcriber])
        consoleLogger.logDetailed("SpeechAnalyzer asset status[\(locale.identifier)]: \(String(describing: initialStatus))")

        if initialStatus == .installed {
            return
        }

        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            let latestStatus = await AssetInventory.status(forModules: [transcriber])
            if latestStatus == .installed {
                return
            }
            throw LocalTranscriptionError.assetInstallationFailed(
                "SpeechAnalyzer 用モデルの取得要求を作成できませんでした"
            )
        }

        consoleLogger.logDetailed("SpeechAnalyzer 用モデルを自動ダウンロードします: \(locale.identifier)")
        progress = 0.05

        do {
            try await request.downloadAndInstall()
        } catch {
            throw LocalTranscriptionError.assetInstallationFailed(error.localizedDescription)
        }

        let finalStatus = await AssetInventory.status(forModules: [transcriber])
        consoleLogger.logDetailed("SpeechAnalyzer asset status after install[\(locale.identifier)]: \(String(describing: finalStatus))")

        guard finalStatus == .installed else {
            throw LocalTranscriptionError.assetInstallationFailed(
                "SpeechAnalyzer 用モデルのインストール完了を確認できませんでした"
            )
        }

        progress = 0.15
    }

    public func transcribe(audioURL: URL) async throws -> String {
        isTranscribing = true
        progress = 0.0

        do {
            try await setup()
            guard let analyzer, let transcriber else {
                throw LocalTranscriptionError.notSupported
            }

            // 音声ファイルをロード
            let audioFile = try AVAudioFile(forReading: audioURL)
            consoleLogger.logDetailed("[MemoraSTT] Audio file loaded: \(audioFile.length) frames, format: \(audioFile.processingFormat)")

            guard audioFile.length > 0 else {
                throw LocalTranscriptionError.transcriptionFailed(
                    NSError(domain: "MemoraSTT", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "Audio file has no audio data"
                    ])
                )
            }

            progress = 0.2
            consoleLogger.logDetailed("[MemoraSTT] SpeechAnalyzer: analyzeSequence(from:) 開始 (offlineTranscription)")

            // ★ 結果を並行で消費（これがないと結果が失われる）
            let resultsTask = Task<[String], Error> {
                var parts: [String] = []
                for try await result in transcriber.results {
                    // result.text は AttributedString 型。
                    // .description は属性辞書のデバッグ表現 "{}" を付けるため、
                    // .characters からプレーンテキストを抽出する。
                    let text = String(result.text.characters)
                    if !text.isEmpty {
                        parts.append(text)
                    }
                }
                return parts
            }

            // 音声投入（高レベルAPI: MP3 を直接渡す）
            do {
                if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                    consoleLogger.logDetailed("[MemoraSTT] analyzeSequence 完了 — finalizing through lastSample")
                    try await analyzer.finalizeAndFinish(through: lastSample)
                } else {
                    consoleLogger.logDetailed("[MemoraSTT] analyzeSequence returned nil — canceling")
                    await analyzer.cancelAndFinishNow()
                }
            } catch {
                consoleLogger.logDetailed("[MemoraSTT] analyzeSequence error: \(error)")
                resultsTask.cancel()
                throw LocalTranscriptionError.transcriptionFailed(error)
            }

            // 結果取得
            let transcriptParts = try await resultsTask.value
            let transcript = transcriptParts.joined(separator: "\n")

            await MainActor.run {
                progress = 1.0
                isTranscribing = false
            }

            if transcript.isEmpty {
                consoleLogger.logDetailed("[MemoraSTT] SpeechAnalyzer: 結果が空 — フォールバックへ")
                throw LocalTranscriptionError.transcriptionFailed(
                    NSError(domain: "MemoraSTT", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "SpeechAnalyzer produced no transcript"
                    ])
                )
            }

            consoleLogger.logDetailed("[MemoraSTT] SpeechAnalyzer: 文字起こし成功 (\(transcript.count)文字)")
            return transcript
        } catch {
            await MainActor.run {
                isTranscribing = false
            }
            throw LocalTranscriptionError.transcriptionFailed(error)
        }
    }
}
