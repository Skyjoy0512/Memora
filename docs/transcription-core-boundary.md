# 文字起こしコア境界

## 目的
- 文字起こし機能を Memora の最重要コアとして保護する。
- Claude Code などのエージェントが、明示依頼なしに STT コアへ触れないようにする。
- SpeechAnalyzer、SFSpeechRecognizer、将来の WhisperLargeTurbo 系統を同じ設計の中で管理する。

## コア所有ファイル
- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/STTSupportTypes.swift`
- `Memora/Core/Services/SpeakerDiarizationService.swift`
- `Memora/Core/Services/SpeakerProfileStore.swift`
- `Memora/Core/Services/TranscriptionEngine.swift`
- `Memora/Core/Networking/AIService.swift`
- `Memora/Core/Contracts/CoreDTOs.swift`

## 現在のバックエンド選択順
1. iOS 26 以上では `SpeechAnalyzer`
2. `SpeechAnalyzer` が使えない条件では `SFSpeechRecognizer`
3. API モードでは OpenAI Whisper API などのクラウド

## 責務境界
- `STTService` を STT orchestration の中心とする。
- `STTService` は task lifecycle、backend selection、chunk execution、event stream、cancellation、chunk merge を持つ。
- `TranscriptionEngine` は ViewModel から呼びやすい facade とし、設定反映と UI 向け progress bridge に責務を限定する。
- backend selection の真実は `STTService.swift` にのみ置く。

## 将来のローカル拡張
- `WhisperLargeTurbo` はローカル STT の第3候補ではなく、`SpeechAnalyzer` 非対応端末向けの高精度バックエンド候補として扱う。
- 実装前提:
  - iOS 配布サイズ
  - 初回モデルダウンロード戦略
  - バッテリーと発熱
  - オフライン利用時の UX
  - 話者分離と埋め込み抽出の整合

## Omi 参照の導入方針
- Omi 由来で優先的に真似するのは次の順序:
  1. 話者分離の安定化
  2. 話者サンプル抽出
  3. 自分の声登録
  4. 話者埋め込みマッチング
  5. 自分の声の自動ラベル付けまたは除外

## Omi 連携境界
- production の Omi path は official SDK ベースの adapter に閉じ込める。
- `BluetoothAudioService` は generic BLE の experimental path とし、Omi production path の source of truth にしない。
- Omi の live transcript は preview 用に限定し、保存済み final transcript の source of truth は Memora の STT pipeline に置く。
- Omi 由来の audio は通常の `AudioFile` として取り込み、その後の transcription / summary / export は既存 pipeline に流す。
- Omi 固有機能の追加は adapter 配下で吸収し、STT コアや SwiftData 保存形式へ直接侵食させない。

## 実装ガードレール
- STT コアを触る変更は、UI 修正と混ぜない。
- 1 PR 1 目的を守る。
- 話者分離ロジック変更時は、保存フォーマット変更と切り離す。
- 話者登録機能は、埋め込み抽出の仕様が決まるまで SwiftData モデルを確定しない。
- 既存の `Transcript` 保存形式を壊す変更は、Migration 設計なしで入れない。

## 参考
- Omi リポジトリ: <https://github.com/BasedHardware/omi>
- WhisperKit: <https://github.com/argmaxinc/WhisperKit>
