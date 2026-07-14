# 04. 一覧ステータス表示 & 失敗リカバリ UX 詳細設計書

Lane: A (UI) + 軽微な Observable 追加 / **STT コア変更: なし(禁止)**
依存: 01(FileDetail の「…」Menu)/ 対応 PR: PR-A6, PR-A7

---

## 1. 目的

PLAUD Note は「ファイルが今どの処理段階か」がリストで見え、失敗はユーザーにほぼ露出しない。Memora は処理状態が FileDetail を開かないと分からず、失敗はテキストだけのアラート。これを (1) 一覧バッジ、(2) 失敗アラートのアクションボタン化、で埋める。

## 2. 現状(確認済み)

- `AudioFileRow` は `isTranscribed / isSummarized` の**静的** StatusChip のみ。実行中・失敗の表示なし。
- 処理状態の source of truth は `FileDetailViewModel`(画面ローカル)+ `ProcessingJob`(SwiftData、`status == "failed"` 等)。**アプリ全体で「どのファイルが今処理中か」を知る仕組みがない。**
- 失敗アラートは `errorMessage + recoveryAction` のテキスト連結表示のみ(`FileDetailView` の `.alert("エラー")`)。`retryLastFailedJob()` は VM に実装済みだが UI から到達しづらい。
- `STTFailureCategory` に7分類と `recoveryAction` 文言が実装済み。

## 3. PR-A6: アプリ全域の処理ステータスレジストリ + 一覧バッジ

### 3.1 新規ファイル: `Memora/Core/Services/ProcessingStatusCenter.swift`

FileDetail を閉じてもバッジが生きるよう、軽量なプロセス内レジストリを追加する。SwiftData には書かない(揮発でよい。永続的な失敗は既存 `ProcessingJob` が持つ)。

```swift
import Foundation
import Observation

/// ファイル単位の処理状態をアプリ全域へ通知する軽量レジストリ。
/// SwiftData には保存しない(プロセス内揮発)。永続的な失敗記録は ProcessingJob が担う。
@MainActor
@Observable
final class ProcessingStatusCenter {
    static let shared = ProcessingStatusCenter()

    enum Phase: Equatable {
        case transcribing(progress: Double)
        case summarizing(progress: Double)
        case failed(jobType: String)   // "transcription" / "summary"
    }

    private(set) var phases: [UUID: Phase] = [:]

    func setTranscribing(fileID: UUID, progress: Double) {
        phases[fileID] = .transcribing(progress: progress)
    }

    func setSummarizing(fileID: UUID, progress: Double) {
        phases[fileID] = .summarizing(progress: progress)
    }

    func setFailed(fileID: UUID, jobType: String) {
        phases[fileID] = .failed(jobType: jobType)
    }

    func clear(fileID: UUID) {
        phases.removeValue(forKey: fileID)
    }

    func phase(for fileID: UUID) -> Phase? { phases[fileID] }
}
```

### 3.2 発行側: `FileDetailViewModel` へのフック(コア外)

`FileDetailViewModel` の既存イベントハンドラに追記する(**PipelineCoordinator / STTService は触らない**):

- `startTranscription()` 冒頭: `ProcessingStatusCenter.shared.setTranscribing(fileID: audioFile.id, progress: 0)`
- `startTranscriptionProgressTracking()` のポーリングループ内(既存の 100ms ループ): `setTranscribing(fileID:progress:)` を併記
- `handleTranscriptionPipelineEvent` の `.completed`: `clear(fileID:)`
- 同 `.failed`: `setFailed(fileID: audioFile.id, jobType: "transcription")`
- 要約系(`startSummarization` / `handleSummarizationPipelineEvent`)も同様に `setSummarizing` / `clear` / `setFailed(jobType: "summary")`

注意: VM は `@MainActor` 前提(■確認: クラス宣言のアクタ属性。非 MainActor なら `Task { @MainActor in ... }` で包む)。

起動時の失敗復元: Home 表示時に「未クリアの failed ProcessingJob」をバッジへ反映したい場合は、`HomeViewModel.loadAudioFiles()` 後に `ProcessingJob` を fetch して `setFailed` を流し込む(retryCount 上限 `canRetry == false` のものは対象外)。■確認: `ProcessingJob` に `audioFileID` があること(確認済み: ある)。

### 3.3 表示側: `AudioFileRow` へバッジ追加

`AudioFileRow` に環境から状態を引く(row は多数生成されるため、`@Environment` ではなくプロパティ渡しでも可。実装簡潔さ優先で shared 直参照+`@Observable` 追跡を使う):

```swift
// AudioFileRow.swift — Row 3: Status chips の分岐を差し替え
private var processingPhase: ProcessingStatusCenter.Phase? {
    ProcessingStatusCenter.shared.phase(for: audioFile.id)
}

// body 内 Row 3:
HStack(spacing: MemoraSpacing.xxs) {
    switch processingPhase {
    case .transcribing(let p):
        ProcessingChip(title: "文字起こし中 \(Int(p * 100))%", color: MemoraColor.accentBlue)
    case .summarizing(let p):
        ProcessingChip(title: "要約中 \(Int(p * 100))%", color: MemoraColor.accentBlue)
    case .failed(let jobType):
        StatusChip(
            title: jobType == "transcription" ? "文字起こし失敗" : "要約失敗",
            color: MemoraColor.accentRed
        )
    case nil:
        if audioFile.isTranscribed {
            StatusChip(title: "文字起こし済", color: MemoraColor.accentGreen)
        } else {
            StatusChip(title: "未文字起こし", color: MemoraColor.textTertiary)
        }
        if audioFile.isSummarized {
            StatusChip(title: "要約済", color: MemoraColor.accentGreen)
        }
    }
}
```

`ProcessingChip`(同ファイルに追加、進捗を示す小さなスピナー付き):

```swift
struct ProcessingChip: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.mini)
            Text(title)
                .font(MemoraTypography.chatToken)
                .foregroundStyle(MemoraColor.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay { Capsule().stroke(color.opacity(0.5), lineWidth: 1) }
        .clipShape(Capsule())
    }
}
```

`@Observable` の変更追跡は View の body が `phases` を読むことで成立するが、**shared 直読みだと row の再評価が List 全体に波及しないか確認**(■確認: 実機でスクロール性能。問題があれば `HomeView` が `ProcessingStatusCenter.shared` を `@State` 保持し、`phases` を row にプロパティで渡す方式へ切替)。

### 3.4 AC

1. Home に居ながら別ファイルの文字起こしが進むと、該当行に「文字起こし中 nn%」チップが出て進捗が更新される(FileDetail から Home へ戻った直後のケースで確認)。
2. 完了で「文字起こし済」に、失敗で赤「文字起こし失敗」に切り替わる。
3. アプリ再起動後、進行中チップは消え(揮発)、`ProcessingJob` に failed が残るファイルは赤チップが復元される。
4. 一覧スクロールが目視で滑らか(60fps 目安)。

## 4. PR-A7: 失敗アラートのアクション化

### 4.1 変更対象
- `Memora/Views/FileDetail/FileDetailView.swift`(`.alert("エラー")` の差し替え)
- `Memora/Core/ViewModels/FileDetailViewModel.swift`(分類の公開)
- `Memora/Views/STTDiagnosticsView.swift`(変更なし、遷移先として利用)

### 4.2 設計

`STTFailureCategory` に応じてアラートのボタンを可変にする:

| category | 主ボタン | 実装 |
|---|---|---|
| `permissionDenied` | 「設定を開く」 | `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)` |
| `assetNotInstalled` / `timeout` | 「再試行」+「API モードで再試行」 | 再試行 = `vm.retryLastFailedJob()` / API 再試行 = §4.3 |
| `apiModeUnavailable` | 「設定を開く(アプリ内)」 | 設定タブへの誘導は Tab 間遷移が必要なため、文言のみ+「OK」。(タブ遷移 Binding の追加は 09 follow-up) |
| `localeUnsupported` / `formatMismatch` / `other` / nil | 「再試行」 | `vm.retryLastFailedJob()` |
| 共通 | 「診断を見る」 | sheet で `STTDiagnosticsView` |

### 4.3 VM 変更

```swift
// FileDetailViewModel に追加
var lastFailureCategory: STTFailureCategory?

// userFacingTranscriptionErrorMessage(for:) 内で分類済みの category を保持:
lastFailureCategory = category

// 「API モードで再試行」用(このセッション限りのモード上書き):
func retryTranscriptionWithAPIMode() {
    // ■確認せよ: currentTranscriptionMode の供給元は @AppStorage("transcriptionMode")。
    // 恒久変更はユーザー同意なしに行わない。VM に一時上書きフィールドを設け、
    // startTranscription() が参照する transcriptionMode を差し替える実装とする。
    transcriptionModeOverride = .api
    startTranscription()
}
private var transcriptionModeOverride: TranscriptionMode?
```

`startTranscription()` 内で `pipelineCoordinator.runTranscriptionPipeline(..., transcriptionMode: transcriptionModeOverride ?? currentTranscriptionMode)` とし、開始直後に `transcriptionModeOverride = nil` へ戻す。API キー未設定なら `apiModeUnavailable` の既存エラーメッセージに自然に落ちる(追加ハンドリング不要)。

### 4.4 View 変更

```swift
@State private var showDiagnostics = false

.alert(
    vm.lastFailureCategory?.localizedTitle ?? "エラー",
    isPresented: $vm.showErrorAlert
) {
    switch vm.lastFailureCategory {
    case .permissionDenied:
        Button("設定を開く") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    case .assetNotInstalled, .timeout:
        Button("再試行") { vm.retryLastFailedJob() }
        Button("API モードで再試行") { vm.retryTranscriptionWithAPIMode() }
    default:
        Button("再試行") { vm.retryLastFailedJob() }
    }
    Button("診断を見る") { showDiagnostics = true }
    Button("閉じる", role: .cancel) {
        vm.errorMessage = nil
        vm.recoveryAction = nil
    }
} message: {
    if let message = vm.errorMessage {
        if let recovery = vm.recoveryAction {
            Text("\(message)\n\n\(recovery)")
        } else {
            Text(message)
        }
    }
}
.sheet(isPresented: $showDiagnostics) {
    NavigationStack { STTDiagnosticsView() }
}
```

注意: 要約失敗(`STTFailureCategory` 対象外)は従来アラートのまま。`vm.lastFailureCategory` は文字起こし失敗時のみ設定し、アラート dismiss 時に nil へ戻す。iOS のアラートはボタン最大数の制約はないが、4ボタン超で縦積みになる — 上記構成(最大4)は許容。

また 01/S-4 の「…」Menu に「文字起こし診断」項目を有効化する(コメントアウトを解除し `showDiagnostics = true`)。

### 4.5 AC

1. 権限拒否状態(iOS 設定で音声認識を拒否)で文字起こし → アラートタイトル「音声認識の権限がありません」+「設定を開く」ボタン → iOS 設定が開く。
2. タイムアウト失敗 → 「再試行」「API モードで再試行」「診断を見る」「閉じる」。API キー設定済みなら API 再試行が実際に API 経路で走る(診断ログの backend が `cloudAPI` になる)。
3. API モード再試行は**そのセッション1回限り**で、`@AppStorage` の transcriptionMode を書き換えない(設定画面の表示が変わらない)。
4. 「診断を見る」で `STTDiagnosticsView` が sheet 表示される。
5. `retryLastFailedJob` の `retryCount` 加算・`canRetry` 上限の既存挙動が維持される。

## 5. PR 分割

| PR | 内容 | 変更ファイル |
|---|---|---|
| PR-A6 | ProcessingStatusCenter + 一覧バッジ | 新規 `ProcessingStatusCenter.swift`, `FileDetailViewModel.swift`(フックのみ), `AudioFileRow.swift`, `HomeViewModel.swift`(失敗復元) |
| PR-A7 | 失敗アラートのアクション化 + 診断導線 | `FileDetailView.swift`, `FileDetailViewModel.swift` |
