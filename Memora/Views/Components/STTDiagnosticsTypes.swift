import SwiftUI
import Speech

// MARK: - SpeechAnalyzerInspection

struct SpeechAnalyzerInspection {
    let canUseSpeechAnalyzer: Bool
    let fallbackReason: String
    let assetBadge: String
    let assetTone: STTDiagnosticsTone
    let assetSummary: String
    let assetDetails: [String]
    let testSummary: String
}

// MARK: - Snapshot

struct STTDiagnosticsSnapshot {
    let backendPanel: STTDiagnosticsPanel
    let assetPanel: STTDiagnosticsPanel
    let fallbackReason: String
    let testSummary: String
    let diagnosticModeLabel: String
    let generatedAt: Date
    let lastFailureCategory: STTFailureCategory?

    private static let generatedAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return f
    }()

    var generatedAtText: String {
        Self.generatedAtFormatter.string(from: generatedAt)
    }
}

// MARK: - Runner

enum STTDiagnosticsRunner {
    static func makeSnapshot(
        mode: TranscriptionMode,
        provider: AIProvider,
        speechAnalyzerEnabled: Bool,
        apiKeyConfigured: Bool,
        performFullTest: Bool
    ) async -> STTDiagnosticsSnapshot {
        switch mode {
        case .api:
            return makeAPISnapshot(provider: provider, apiKeyConfigured: apiKeyConfigured)
        case .local:
            return await makeLocalSnapshot(
                speechAnalyzerEnabled: speechAnalyzerEnabled,
                performFullTest: performFullTest
            )
        }
    }

    private static func makeAPISnapshot(
        provider: AIProvider,
        apiKeyConfigured: Bool
    ) -> STTDiagnosticsSnapshot {
        let supportsTranscription = provider.supportsTranscription
        let backendStatus: STTDiagnosticsTone = supportsTranscription && apiKeyConfigured ? .success : .warning
        let fallbackReason: String

        if !supportsTranscription {
            fallbackReason = "選択中の \(provider.rawValue) は API 文字起こし未対応のため、API モードでは開始できません。OpenAI を選択してください。"
        } else if !apiKeyConfigured {
            fallbackReason = "API キーが未設定のため、CloudSTTBackend を開始できません。"
        } else {
            fallbackReason = "フォールバックは発生していません。現在は \(provider.rawValue) API を使用予定です。"
        }

        return STTDiagnosticsSnapshot(
            backendPanel: STTDiagnosticsPanel(
                title: "Backend Status",
                badgeText: supportsTranscription ? "API" : "要修正",
                tone: backendStatus,
                summary: supportsTranscription ? "\(provider.rawValue) API を使用予定" : "API 文字起こしに未対応",
                details: [
                    "文字起こしモード: API",
                    "選択プロバイダー: \(provider.rawValue)",
                    "API キー: \(apiKeyConfigured ? "設定済み" : "未設定")"
                ]
            ),
            assetPanel: STTDiagnosticsPanel(
                title: "Asset Status",
                badgeText: "N/A",
                tone: .neutral,
                summary: "API モードでは SpeechAnalyzer asset は使用しません。",
                details: [
                    "ローカルモデル: 未使用",
                    "SpeechAnalyzer asset: チェック対象外"
                ]
            ),
            fallbackReason: fallbackReason,
            testSummary: supportsTranscription
                ? "API backend の設定整合性を確認しました。"
                : "API backend の選択条件を満たしていないため、設定の修正が必要です。",
            diagnosticModeLabel: "設定チェック",
            generatedAt: Date(),
            lastFailureCategory: STTFailureCategory.classifyLastFailure()
        )
    }

    private static func makeLocalSnapshot(
        speechAnalyzerEnabled: Bool,
        performFullTest: Bool
    ) async -> STTDiagnosticsSnapshot {
        let locale = Locale(identifier: "ja_JP")
        let authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        let recognizer = SFSpeechRecognizer(locale: locale)
        let recognizerAvailable = recognizer?.isAvailable ?? false

        #if targetEnvironment(simulator)
        let simulatorReason = "シミュレータでは SpeechAnalyzer を使わず、SFSpeechRecognizer へフォールバックします。"
        #else
        let simulatorReason = ""
        #endif

        if #available(iOS 26.0, *), speechAnalyzerEnabled {
            if performFullTest {
                let result = await SpeechAnalyzerPreflight().run(locale: locale)
                return makeSpeechAnalyzerSnapshot(
                    locale: locale,
                    authorizationStatus: authorizationStatus,
                    recognizerAvailable: recognizerAvailable,
                    simulatorReason: simulatorReason,
                    result: result
                )
            }

            let inspection = await inspectSpeechAnalyzer(locale: locale)
            return makeSpeechAnalyzerSnapshot(
                locale: locale,
                authorizationStatus: authorizationStatus,
                recognizerAvailable: recognizerAvailable,
                simulatorReason: simulatorReason,
                inspection: inspection
            )
        }

        let fallbackReason: String
        if !simulatorReason.isEmpty {
            fallbackReason = simulatorReason
        } else if speechAnalyzerEnabled {
            fallbackReason = "現在の OS では SpeechAnalyzer を使えないため、SFSpeechRecognizer を使用します。"
        } else {
            fallbackReason = "SpeechAnalyzer ベータ機能が OFF のため、SFSpeechRecognizer を使用します。"
        }

        let recognizerTone: STTDiagnosticsTone = recognizerAvailable ? .success : .warning
        return STTDiagnosticsSnapshot(
            backendPanel: STTDiagnosticsPanel(
                title: "Backend Status",
                badgeText: "SpeechRecognizer",
                tone: recognizerTone,
                summary: recognizerAvailable
                    ? "SFSpeechRecognizer を使用予定です。"
                    : "SFSpeechRecognizer の利用可否を再確認してください。",
                details: [
                    "文字起こしモード: ローカル",
                    "SpeechAnalyzer トグル: \(speechAnalyzerEnabled ? "ON" : "OFF")",
                    "Speech 権限: \(authorizationStatus.label)",
                    "SFSpeechRecognizer: \(recognizerAvailable ? "利用可能" : "利用不可")"
                ]
            ),
            assetPanel: STTDiagnosticsPanel(
                title: "Asset Status",
                badgeText: "未使用",
                tone: .neutral,
                summary: "この構成では SpeechAnalyzer asset を使用しません。",
                details: [
                    "SpeechAnalyzer: \(speechAnalyzerEnabled ? "OS 非対応" : "無効")",
                    "on-device asset: チェック対象外"
                ]
            ),
            fallbackReason: fallbackReason,
            testSummary: recognizerAvailable
                ? "SFSpeechRecognizer backend の基本状態を確認しました。"
                : "SFSpeechRecognizer の権限または availability を見直してください。",
            diagnosticModeLabel: "設定チェック",
            generatedAt: Date(),
            lastFailureCategory: STTFailureCategory.classifyLastFailure()
        )
    }

    @available(iOS 26.0, *)
    private static func makeSpeechAnalyzerSnapshot(
        locale: Locale,
        authorizationStatus: SFSpeechRecognizerAuthorizationStatus,
        recognizerAvailable: Bool,
        simulatorReason: String,
        inspection: SpeechAnalyzerInspection
    ) -> STTDiagnosticsSnapshot {
        let backendTone: STTDiagnosticsTone = inspection.canUseSpeechAnalyzer ? .success : .warning
        let fallbackReason = inspection.canUseSpeechAnalyzer
            ? "フォールバックは発生していません。SpeechAnalyzer を優先できます。"
            : inspection.fallbackReason

        return STTDiagnosticsSnapshot(
            backendPanel: STTDiagnosticsPanel(
                title: "Backend Status",
                badgeText: inspection.canUseSpeechAnalyzer ? "SpeechAnalyzer" : "Fallback",
                tone: backendTone,
                summary: inspection.canUseSpeechAnalyzer
                    ? "SpeechAnalyzer を優先して使用できます。"
                    : "SpeechAnalyzer 条件を満たさず、SFSpeechRecognizer を使用予定です。",
                details: [
                    "文字起こしモード: ローカル",
                    "SpeechAnalyzer トグル: ON",
                    "Speech 権限: \(authorizationStatus.label)",
                    "SFSpeechRecognizer: \(recognizerAvailable ? "利用可能" : "利用不可")"
                ]
            ),
            assetPanel: STTDiagnosticsPanel(
                title: "Asset Status",
                badgeText: inspection.assetBadge,
                tone: inspection.assetTone,
                summary: inspection.assetSummary,
                details: inspection.assetDetails
            ),
            fallbackReason: simulatorReason.isEmpty ? fallbackReason : simulatorReason,
            testSummary: inspection.testSummary,
            diagnosticModeLabel: "高速チェック",
            generatedAt: Date(),
            lastFailureCategory: STTFailureCategory.classifyLastFailure()
        )
    }

    @available(iOS 26.0, *)
    private static func makeSpeechAnalyzerSnapshot(
        locale: Locale,
        authorizationStatus: SFSpeechRecognizerAuthorizationStatus,
        recognizerAvailable: Bool,
        simulatorReason: String,
        result: SpeechAnalyzerPreflightResult
    ) -> STTDiagnosticsSnapshot {
        let backendDetails = [
            "文字起こしモード: ローカル",
            "SpeechAnalyzer トグル: ON",
            "Speech 権限: \(authorizationStatus.label)",
            "SFSpeechRecognizer: \(recognizerAvailable ? "利用可能" : "利用不可")"
        ]

        switch result {
        case .ready(let diagnostics):
            return STTDiagnosticsSnapshot(
                backendPanel: STTDiagnosticsPanel(
                    title: "Backend Status",
                    badgeText: "SpeechAnalyzer",
                    tone: .success,
                    summary: "SpeechAnalyzer preflight を通過し、優先使用できます。",
                    details: backendDetails
                ),
                assetPanel: STTDiagnosticsPanel(
                    title: "Asset Status",
                    badgeText: diagnostics.assetStatus,
                    tone: .success,
                    summary: "SpeechAnalyzer asset と locale の整合性を確認しました。",
                    details: makeSpeechAnalyzerAssetDetails(
                        locale: locale,
                        diagnostics: diagnostics
                    )
                ),
                fallbackReason: simulatorReason.isEmpty
                    ? "フォールバックは発生していません。SpeechAnalyzer を優先できます。"
                    : simulatorReason,
                testSummary: "SpeechAnalyzer preflight を実行し、availability / locale / asset / audio format を確認しました。",
                diagnosticModeLabel: "preflight 実行",
                generatedAt: Date(),
                lastFailureCategory: nil
            )

        case .unavailable(let reason, let diagnostics):
            return STTDiagnosticsSnapshot(
                backendPanel: STTDiagnosticsPanel(
                    title: "Backend Status",
                    badgeText: "Fallback",
                    tone: .warning,
                    summary: "SpeechAnalyzer preflight が通らないため、SFSpeechRecognizer を使用予定です。",
                    details: backendDetails
                ),
                assetPanel: STTDiagnosticsPanel(
                    title: "Asset Status",
                    badgeText: diagnostics.assetStatus == "unknown" ? "未準備" : diagnostics.assetStatus,
                    tone: .warning,
                    summary: reason.description,
                    details: makeSpeechAnalyzerAssetDetails(
                        locale: locale,
                        diagnostics: diagnostics
                    )
                ),
                fallbackReason: simulatorReason.isEmpty ? reason.description : simulatorReason,
                testSummary: "SpeechAnalyzer preflight を実行し、フォールバック条件を確認しました。",
                diagnosticModeLabel: "preflight 実行",
                generatedAt: Date(),
                lastFailureCategory: STTFailureCategory.classifyLastFailure()
            )
        }
    }

    @available(iOS 26.0, *)
    private static func makeSpeechAnalyzerAssetDetails(
        locale: Locale,
        diagnostics: SpeechAnalyzerDiagnostics
    ) -> [String] {
        [
            "要求 locale: \(locale.identifier)",
            "解決 locale: \(diagnostics.supportedLocale?.identifier ?? "なし")",
            "asset state: \(diagnostics.assetStatus)",
            "互換 audio format: \(diagnostics.compatibleFormatsDescription)",
            String(format: "preflight: %.1fms", diagnostics.checkDurationMs)
        ]
    }

    @available(iOS 26.0, *)
    private static func inspectSpeechAnalyzer(locale: Locale) async -> SpeechAnalyzerInspection {
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return SpeechAnalyzerInspection(
                canUseSpeechAnalyzer: false,
                fallbackReason: "SpeechAnalyzer が \(locale.identifier) と等価な locale を解決できないため、SFSpeechRecognizer にフォールバックします。",
                assetBadge: "locale NG",
                assetTone: .warning,
                assetSummary: "SpeechAnalyzer locale が未対応です。",
                assetDetails: [
                    "要求 locale: \(locale.identifier)",
                    "supported locale: なし"
                ],
                testSummary: "SpeechAnalyzer locale 判定で停止しました。"
            )
        }

        let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .transcription)
        let assetStatus = await AssetInventory.status(forModules: [transcriber])
        let compatibleFormats = await transcriber.availableCompatibleAudioFormats
        let formatLine = compatibleFormats.isEmpty
            ? "互換 audio format: 取得なし"
            : "互換 audio format: \(compatibleFormats.prefix(2).map { String(describing: $0) }.joined(separator: ", "))"

        if assetStatus == .installed {
            return SpeechAnalyzerInspection(
                canUseSpeechAnalyzer: true,
                fallbackReason: "フォールバックは発生していません。SpeechAnalyzer asset はインストール済みです。",
                assetBadge: "installed",
                assetTone: .success,
                assetSummary: "SpeechAnalyzer asset は利用可能です。",
                assetDetails: [
                    "要求 locale: \(locale.identifier)",
                    "解決 locale: \(supportedLocale.identifier)",
                    "asset state: \(String(describing: assetStatus))",
                    formatLine
                ],
                testSummary: "現在の asset / locale 状態から SpeechAnalyzer を優先できると判定しました。"
            )
        }

        return SpeechAnalyzerInspection(
            canUseSpeechAnalyzer: false,
            fallbackReason: "SpeechAnalyzer asset が \(String(describing: assetStatus)) のため、準備完了まで SFSpeechRecognizer にフォールバックします。",
            assetBadge: String(describing: assetStatus),
            assetTone: .warning,
            assetSummary: "SpeechAnalyzer asset はまだ準備完了ではありません。",
            assetDetails: [
                "要求 locale: \(locale.identifier)",
                "解決 locale: \(supportedLocale.identifier)",
                "asset state: \(String(describing: assetStatus))",
                formatLine
            ],
            testSummary: "現在の asset 状態からフォールバック候補を判定しました。"
        )
    }
}

// MARK: - SFSpeechRecognizerAuthorizationStatus Label

extension SFSpeechRecognizerAuthorizationStatus {
    var label: String {
        switch self {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "unknown"
        }
    }
}
