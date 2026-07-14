# Memora RN / Expo

This is the parallel React Native / Expo frontend for Memora.

Read the root migration handoff first:

- `../../docs/react-native-expo-migration-plan.md`

## Current Status

- Expo SDK 57.
- Expo Router enabled.
- Mock UI screens implemented for Home, File Detail, Ask AI, Settings, and Preview Index.
- `expo-dev-client` installed.
- iOS native project generated under `ios/`.
- Local Expo Module shell exists at `modules/memora-native`.
- RN facade prefers the native `MemoraNative` module on iOS and uses mock data on web.
- `MemoraNative` currently reads native-file metadata through `MemoraAudioFileReading` and falls back to a safe sample file when no local native-file records exist; it is not wired to the real SwiftData/repository or STT services yet.
- `loadSettings`/`saveSettings` route through `MemoraSettingsReadingWriting`; the default iOS store persists non-secret settings in `UserDefaults` and can still be replaced by a host-app settings/keychain adapter.
- `startRecording`/`stopRecording`/`importAudio` route through `MemoraRecordingImportHandling`; the default handler is `MemoraNativeFileRecordingImportHandler`, which records/imports local files under app Documents and returns DTOs.
- Home recording/import buttons now call the facade, import uses `expo-document-picker`, and the bridge status panel shows recording session plus returned file DTO review.
- Home inserts recording/import results into the visible file list immediately, then silently refreshes from the bridge.
- Home refreshes file data again when the screen regains focus, supports pull-to-refresh, and has a refresh icon in the Recent Files header.
- Web fallback keeps generated files in memory for the current review session so browser review matches the native list-update flow.
- Native file recording/import is persisted to the Expo module's local JSON metadata store, but not into the existing SwiftData/repository source of truth yet.
- `renameAudioFile`/`deleteAudioFile` are available on the native bridge for local native-file metadata. Delete is wired in Home for safe generated/native-file rows, and rename is wired in File Detail for those same bridge records.
- Audio-file create/rename/delete now route through `MemoraAudioFileMutating` and `MemoraNativeAudioFileMutationRegistry`, so a host-app SwiftData/repository mutator can replace the local JSON metadata store later.
- `ios/MemoraRN/AppDelegate.swift` calls `MemoraNativeBridgeBootstrap.configureDefaults()` before React Native starts. `ios/MemoraRN/MemoraNativeBridgeBootstrap.swift` currently injects the native-file defaults and exposes `configure(...)` as the single startup hook for future SwiftData/repository adapters.
- Settings includes editable non-secret controls plus a Bridge section that reports platform, module name, audio-file source, recording source, settings source, and whether real data is connected.
- Ask AI now supports file/project/global scope switching, scoped message history, empty state, loading state, text input, `MemoraNative.queryKnowledge`, generated mock/native sample answers, and source pills for review.
- Summary generation now has a typed `MemoraNative.generateSummary` boundary with native/web sample implementations and `summarySource` diagnostics; the real host-app summarizer is not connected yet.
- File Detail Summary actions call that boundary and render generating, error, and returned-summary states.
- No STT core changes.
- Processing failures can be stored through the native `MemoraFileProcessingRetryQueue`; it deduplicates transcription/summary retries, persists attempt count and the latest error, and removes completed items without invoking STT or AI services itself.

## Commands

```bash
npm run typecheck
npm run web -- --port 8088
npm run ios
npm run qa:ios:build
```

`qa:ios:build` uses a process-specific DerivedData directory under `/tmp` and builds the Apple Silicon simulator architecture (`arm64`) by default. This keeps QA builds isolated from Xcode, Claude, or another agent building the same workspace concurrently. Set `MEMORA_RN_DERIVED_DATA_PATH` when you want to reuse a stable cache, or `MEMORA_RN_ARCHS` for a different architecture set.

After `qa:ios:build` succeeds, run the prepared test bundle on a concrete simulator with:

```bash
MEMORA_RN_DESTINATION='platform=iOS Simulator,name=Memora RN Test,OS=26.5' npm run qa:ios:test
```

For native bridge work:

```bash
npm run prebuild
cd ios && pod install
xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build
npm run ios
```

Use web for quick UI review and Dev Client/native builds for anything that touches `MemoraNative`.

Note: on 2026-07-09, build-only native validation passed, but creating a new simulator device was blocked locally because CoreSimulator could not write to `/Volumes/HIKSEMI/Xcode/CoreSimulator/Devices`.
Fix that storage/permission issue before relying on `npm run ios` for live simulator UI review.

Expected behavior:

- Web: mock files and mock transcription progress for fast design review.
- iOS Dev Client: native-file metadata for list/detail after recording/import, local native-file rename/delete, `Native bridge sample` fallback before any local records exist, native sample progress events, Audio source `native-files`, Mutation source `native-files`, Recording source `native-file`, and Settings source `userdefaults`.

## Native Data Boundary

The current native reader is `MemoraNativeFileAudioFileReader` in `modules/memora-native/ios/MemoraAudioFileDTO.swift`.
It reads JSON metadata written by native-file recording/import and falls back to `MemoraSampleAudioFileReader` when empty.
The same local metadata store also supports bridge-level rename/delete for native-file records; delete removes both the JSON metadata entry and the stored audio file when present.
The current native-file implementation is `MemoraNativeFileAudioFileStore`, which conforms to both `MemoraAudioFileReading` and `MemoraAudioFileMutating`.
Replace it with SwiftData/repository reader and mutator adapters when connecting real app data. Keep DTO conversion inside the adapter/module boundary and do not expose SwiftData model instances directly to React Native.
Use `MemoraNativeBridgeBootstrap.configureDefaults()` in `ios/MemoraRN/MemoraNativeBridgeBootstrap.swift` as the default injection point.
When real app data is ready, call `MemoraNativeBridgeBootstrap.configure(...)` with host-app reader, mutator, recording/import, and settings adapters instead of editing the Expo module internals.
The generated `MemoraRN` Xcode target does not yet compile the existing `Memora/Core` SwiftData models/repositories, so the next real-data step must first decide target sharing: add a narrow file set to the RN target, extract a small shared Swift package/framework, or expose a host-app service layer that owns `ModelContainer`.

The current native settings store is `MemoraUserDefaultsSettingsStore` in `modules/memora-native/ios/MemoraSettingsDTO.swift`.
Replace it through `MemoraNativeSettingsRegistry.settingsStore` from the host app target when wiring the full app settings source of truth. Keep API keys and Keychain-backed secrets in Swift; React Native should only receive non-secret settings state.

The current native recording/import handler is `MemoraNativeFileRecordingImportHandler` in `modules/memora-native/ios/MemoraRecordingBridgeDTO.swift`.
It records `.m4a` files with AVFoundation and copies imported document-picker files under app Documents, then returns JSON-friendly `AudioFileDTO` values.
Replace it through `MemoraNativeRecordingImportRegistry.handler` from the host app target when wiring full app recording/import persistence. The adapter should own or receive `AudioRecorder`, `AudioFileImportService`, and SwiftData/repository dependencies outside protected STT core files.

The current native Ask AI query handler is `MemoraSampleKnowledgeQuery` in `modules/memora-native/ios/MemoraKnowledgeQueryDTO.swift`.
`AskAIScreen` already calls `MemoraNative.queryKnowledge`, and Settings Bridge reports `Knowledge source`.
Replace it through `MemoraNativeKnowledgeQueryRegistry.knowledgeQuery` from the host app target after deciding the real retrieval/query source of truth. Keep AI provider calls and `KnowledgeQueryService` dependencies outside the local Expo module.

The current native summary handler is `MemoraSampleSummaryGenerator` in `modules/memora-native/ios/MemoraSummaryDTO.swift`.
`MemoraNative.generateSummary` accepts an `audioFileId` plus provider/template options and returns a JSON-friendly summary DTO. Replace it through `MemoraNativeSummaryRegistry.summaryGenerator` from the host app after deciding the real summary source of truth. Keep `AIService`, provider SDKs, and Keychain dependencies outside the local Expo module.

## Preview Routes

- `/`
- `/file/weekly-growth-0709`
- `/ask-ai`
- `/settings`
- `/preview`
- `/file/empty-transcript`
- `/file/not-found`

## Boundaries

This app can define UI, mock data, DTOs, and a future native bridge facade.
Do not edit Swift STT core files from this workspace unless the user explicitly asks for STT/core work.
