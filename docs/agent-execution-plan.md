# PR #40 レビュー — 実行計画

## 良い点

1. **FileDetailViewModel の大幅なスリム化**
   `repoFactory` の dual-path 分岐、`setupEngines()`、直接 `modelContext.insert` 等が PipelineCoordinator に押し込められ、ViewModel は「pipeline event を受けて UI state を更新する」だけになった。

2. **PipelineCoordinator の `executeTranscription` 抽出**
   文字起こしパイプラインと要約パイプラインで共通する文字起こし部分が `executeTranscription` にまとまり、`runTranscriptionPipeline` / `runFullPipeline` / `runSummaryOnlyPipeline` の 3 ルートが整理された。

3. **RepositoryFactory の削除（単一経路化）**
   `PipelineCoordinator`, `FileDetailViewModel`, `saveTranscript`, `saveAudioFile`, `loadSavedTranscript` から `repoFactory` 分岐が消え、全て `modelContext` 直叩きに統一された。

4. **CancellationError の明示的ハンドリング**
   `catch is CancellationError` でキャンセル時の無言無視が明示的になった。`continuation.onTermination` で task.cancel() + `transcriptionEngine.cancelActiveTranscription()` を呼ぶ流れも正しい。

5. **CI の Xcode 26 化**
   `macos-26` ランナーで iOS 26 API が解決できるようになった。xcodegen ステップも追加済み。

6. **docs/v1-product-design.md**
   正本 1 枚で outdated 文書との関係が明記されており、新規セッションの迷いが減る。

## 危険な点

1. **PlaudImportService だけ repositoryFactory を使わず ModelContext 直**
   `AudioFileImportService` はまだ `repositoryFactory` パラメータを持っているが、`PlaudImportService` は `modelContext` のみ。方針として正しい（直叩きへ移行中）だが、`importFromExport` 経路が将来使われる際、`AudioFileImportService` 側に repositoryFactory を渡すかどうかで挙動が変わる可能性がある。

2. **OmiAdapter の AudioImportHandler 戻り値が `OmiImportedAudio` に変わった**
   ContentView の `configureOmiAdapterIfNeeded` で `return OmiImportedAudio(...)` を closure 内で組み立てている。この handler の戻り型変更は Omi 統合コミットに含まれており、Plaud とは無関係の変更。

3. **SettingsView / DeviceConnectionView の Omi UI 改善が混在**
   `connectedDeviceName`, `sessionTerminationDescription` の追加は Omi 関連改善。Plaud import とは別レーン。小さいが「依頼範囲外」に該当。

4. **`nonisolated deinit` (AudioRecorder.swift)**
   `macos-26` (Xcode 26.2) では問題なし。CI が通ったので解決済み。

## 今回マージしてよい点

- PipelineCoordinator / FileDetailViewModel の責務整理 → 明確な改善
- RepositoryFactory 削除 → 保存経路の単一化
- STTService への orchestration 集中 → backend selection truth が 1 箇所に
- CancellationError / onTermination の整備
- CI の macos-26 化
- Plaud export file import（モデル + サービス + UI）
- OmiAdapter の改善（handler 戻り値型、接続 UI）
- docs/v1-product-design.md

## マージ前に直したい点

### A. ContentView の `configureOmiAdapterIfNeeded` で OmiImportedAudio を手作り

```swift
// ContentView.swift
return OmiImportedAudio(
    audioFileID: audioFile.id,
    title: audioFile.title,
    importedAt: Date()
)
```

OmiImportedAudio の組み立ては ContentView ではなく `AudioFileImportService` または `OmiAdapter` 側で行う方が自然。後続でも可。

### B. `PlaudImportService.importFromExport` が実質使われていない

`importFromExport` は `AudioFileImportService.importAudio` を呼ぶが、ContentView の Plaud フローは `importTextOnly` しか使っていない。デッドコードではなく将来用。`repositoryFactory` パラメータ欠けの問題があるので、使う直前に実装する方が安全。

→ **判断**: A・B とも後続 PR で問題なし。

## 後続 PR に分けるべき点

| 項目 | 理由 |
|------|------|
| Omi UI 改善（connectedDeviceName / sessionTerminationDescription） | Plaud import とは別レーン (Lane A vs D) |
| `PlaudImportService.importFromExport` の音声同時インポート | P0 だが現状デッドコード。使う時に正しく実装 |
| TranscriptionEngine の thin wrapper 化の評価 | 現状 facade として存在意義があるが、更に薄くなったので将来的に FileDetailViewModel が STTService を直接叩く選択肢も検討 |
| STTService の protocol 抽象（`STTServiceProtocol` / `STTTaskHandleProtocol`） | 個人開発では過剰可能性。テストで mock が必要になった時点で導入でよい |
