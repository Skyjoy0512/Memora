# React Native / Expo Migration Plan

Last updated: 2026-07-14

## Purpose

Memora のフロントエンドを SwiftUI から React Native / Expo へ段階移行するための計画書です。
Claude、Codex、DeepSeek など別の LLM が途中参加しても、ここを読めば移行範囲、禁止事項、現在地、次にやることが分かる状態を保ちます。

このドキュメントは実装中も更新対象です。各作業セッションの最後に、必ず `Progress` と `Handoff Log` を更新してください。

## Current Repo State

- Current app: iOS-first SwiftUI app.
- Current UI stack: `Memora/Views/**`, `Memora/DesignSystem/**`, `Memora/App/**`.
- Current domain/core stack: Swift services, SwiftData models, local files, Keychain, AVFoundation/Speech, AI providers.
- Existing backend: `bot-server/**` Node/TypeScript service. This is not part of the frontend migration.
- Expo app: `apps/mobile-expo` contains the current RN UI and a local Expo module.
- Current bridge boundary: native-file audio/JSON metadata, non-secret UserDefaults settings, and deterministic query/summary placeholders are available. Existing SwiftData, STT, Keychain, and AI-provider services remain outside the RN target.

## Non-Negotiable Boundaries

Do not modify these STT core files unless the user explicitly asks for STT/core changes:

- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/STTSupportTypes.swift`
- `Memora/Core/Services/SpeakerDiarizationService.swift`
- `Memora/Core/Services/SpeakerProfileStore.swift`
- `Memora/Core/Services/TranscriptionEngine.swift`
- `Memora/Core/Networking/AIService.swift`
- `Memora/Core/Contracts/CoreDTOs.swift`

Do not mix UI migration with backend/STT rewrites. Keep `1 PR = 1 purpose`.

## Migration Strategy

Use a parallel app approach first:

1. Add a new Expo app under `apps/mobile-expo`.
2. Rebuild the UI in React Native with mock data so design review is fast.
3. Use Expo Go for mock UI review.
4. Use Expo Dev Client for real native features because custom Swift modules do not run in Expo Go.
5. Keep existing Swift services as the source of truth and expose only thin native bridge APIs to React Native.
6. Switch screens or flows gradually after each flow is visually reviewed and functionally verified.

This avoids a risky big-bang rewrite while still letting the UI move quickly.

## Migration Scope

### Move To React Native

| Area | Current Swift location | Target |
|---|---|---|
| App shell / navigation | `Memora/App/ContentView.swift`, `Memora/Views/V6/**` | Expo Router |
| Home / file list | `Memora/Views/**`, `Memora/Views/V6/**` | RN screens + list components |
| File detail | `Memora/Views/FileDetail/**`, `V6FileDetailView.swift` | RN tabs/screens |
| Transcript UI | `TranscriptTab.swift`, related view helpers | RN transcript view |
| Summary / memo UI | `SummaryTab.swift`, `MemoTab.swift` | RN content/editor surfaces |
| Settings UI | `Memora/Views/Settings/**` | RN settings screens |
| Ask AI UI | `AskAIView.swift`, `Memora/Views/AskAI/**` | RN chat/query screens |
| Design system | `Memora/DesignSystem/**` | RN tokens/components |

### Keep Native / Existing

| Area | Keep as-is initially | RN access pattern |
|---|---|---|
| Recording / playback | Swift services | Native module |
| STT pipeline | Swift STT core | Native module + event stream |
| SwiftData models | `Memora/Core/Models/**` | Native module DTOs |
| Keychain | `KeychainService.swift` | Native module methods |
| AI providers | Swift networking/services | Native module or later API facade |
| Bot server | `bot-server/**` | Existing HTTP API |
| Broadcast extension | `MemoraBroadcastExtension/**` | Keep native |
| Widget | `MemoraWidget/**` | Keep native until separate decision |

## Proposed New Structure

```text
apps/
  mobile-expo/
    app/
      (tabs)/
      file/[id].tsx
      settings/
      ask-ai/
    src/
      components/
      design/
      features/
      native/
      mocks/
      types/
    package.json
    app.json
```

Suggested RN libraries:

- Expo Router for navigation.
- TypeScript for all app code.
- React Native Reusables, Tamagui, or a small local component system for UI.
- Storybook or Expo Router preview routes for screen-by-screen review.
- `expo-dev-client` once native Swift bridge work starts.

Final library choice is still open. Keep the first pass simple enough that design changes remain cheap.

## Native Bridge Surface

Start with a small bridge. Do not expose raw SwiftData models directly.

Suggested module name: `MemoraNative`.

Initial API shape:

- `listAudioFiles(): Promise<AudioFileDTO[]>`
- `getAudioFile(id): Promise<AudioFileDetailDTO>`
- `startRecording(): Promise<RecordingSessionDTO>`
- `stopRecording(): Promise<AudioFileDTO>`
- `importAudio(uri): Promise<AudioFileDTO>`
- `startTranscription(audioFileId): Promise<TranscriptionTaskDTO>`
- `cancelTranscription(taskId): Promise<void>`
- `observeTranscriptionEvents(taskId): EventEmitter`
- `generateSummary({ audioFileId, options }): Promise<SummaryDTO>`
- `saveSettings(settings): Promise<void>`
- `loadSettings(): Promise<SettingsDTO>`
- `renameAudioFile(id, title): Promise<AudioFileDTO | null>`
- `deleteAudioFile(id): Promise<boolean>`

DTOs should be stable JSON-friendly objects. Keep native-only types inside Swift.

## Workstreams

### W0: Documentation And Bootstrap

- [x] Create this migration plan.
- [x] Decide UI library: start with a small owned React Native component system, Expo Router, and Ionicons. Avoid a heavy UI kit until real UI gaps justify it.
- [x] Decide app location: keep the Expo app inside this repo as `apps/mobile-expo`.
- [x] Add package manager strategy: use local npm inside `apps/mobile-expo` for now. Do not convert the root repo into a monorepo yet.

### W1: Expo Mock UI

- [x] Scaffold `apps/mobile-expo`.
- [x] Add Expo Router routes.
- [x] Add design tokens.
- [x] Add mock audio files, transcript, summary, memo, settings, and Ask AI data.
- [x] Build Home, File Detail, Settings, Ask AI screens with mock data.
- [x] Verify with `npm run web -- --port 8088`.

### W2: Visual Review Loop

- [x] Add preview routes or Storybook-style screen index.
- [x] Capture screenshots for Home, File Detail, Transcript, Summary, Settings, Ask AI.
- [x] Record design decisions and remaining visual gaps in this doc.
- [ ] Iterate until the RN UI is clearly better than the current SwiftUI UI.

### W3: Native Bridge Foundation

- [x] Add Expo Dev Client.
- [x] Add iOS native module shell.
- [x] Implement read-only bridge for audio file list/detail.
- [x] Add TypeScript DTO types matching the bridge output.
- [x] Add a read-only Swift DTO/reader adapter boundary that can later swap sample data for SwiftData/service data.
- [x] Add bridge diagnostics to the RN Settings screen.
- [x] Verify on iOS simulator build.

### W4: Real Feature Wiring

- [ ] Connect recording/import.
  - Native-file recording/import bridge is implemented in the Expo module.
  - Native-file metadata rename/delete bridge is implemented in the Expo module.
  - Still pending: host-app adapter that persists returned files into the existing SwiftData/repository source of truth.
- [ ] Connect STT task start/cancel/progress events.
- [ ] Connect transcript display and status recovery.
- [ ] Connect summary generation.
  - RN File Detail action and native/web bridge contract are wired.
  - Still pending: inject the real host-app summary adapter after SwiftData/shared-target ownership is implemented.
- [ ] Connect settings and API-key state through native services.
- [ ] Keep Bot Server API unchanged.

### W5: Cutover And Cleanup

- [ ] Choose cutover strategy: separate target, feature flag, or full app replacement.
- [ ] Run old SwiftUI and RN flows side by side until parity is proven.
- [ ] Remove or freeze replaced SwiftUI screens only after RN parity.
- [ ] Keep Swift core services until a separate backend/native-core migration is explicitly approved.

## Size Estimate

| Milestone | Expected effort | Notes |
|---|---:|---|
| RN/Expo mock UI PoC | 3-5 days | Fast visual loop, no native bridge |
| Main screen MVP | 2-4 weeks | Home, File Detail, Settings, Ask AI with partial real data |
| Full app migration | 6-10 weeks | Recording, STT, summary, settings, edge cases, release hardening |
| Native core rewrite | Out of scope | Requires a separate architecture decision |

## Validation Commands

Use these as the default checks, adjusting only when the project structure changes.

```bash
# Existing iOS app
xcodebuild -project Memora.xcodeproj -scheme Memora -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build

# Bot server
cd bot-server
npm run build

# Future Expo app
cd apps/mobile-expo
npm install
npm run web -- --port 8088
npm run typecheck
```

For Expo native modules:

```bash
cd apps/mobile-expo
npm run prebuild -- --platform ios
cd ios && pod install
xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build
npm run ios
```

## Risks

- Expo Go cannot run custom Swift native modules. Use it for mock UI only.
- SwiftData and STT event streams need carefully designed DTOs; direct model exposure will create churn.
- Audio recording, background behavior, permissions, and broadcast extension behavior are native-heavy and require Dev Client or full native builds.
- A big-bang rewrite could stall STT stabilization and product testing. Keep the old SwiftUI app usable until RN parity is proven.
- Existing uncommitted work may be unrelated. Always inspect `git status` before editing.

## Agent Instructions

Every LLM or agent working on this migration must:

1. Read this file first.
2. Read `CLAUDE.md`.
3. Read `docs/transcription-core-boundary.md` before touching anything near STT.
4. Start each implementation turn with:
   - やること
   - 変更するファイル
   - 変更しないファイル
5. Keep UI, native bridge, STT, and backend changes in separate PRs.
6. Update `Progress` and `Handoff Log` before finishing.
7. Report actual commands run and whether they passed.

## Progress

| Date | Status | Owner/Agent | Summary | Verification | Next |
|---|---|---|---|---|---|
| 2026-07-09 | Planned | Codex | Created migration plan and handoff structure. No code migration started. | Docs only; no build required. | Decide UI library and scaffold `apps/mobile-expo`. |
| 2026-07-09 | In progress | Codex | Scaffolded `apps/mobile-expo` with Expo SDK 57, Expo Router, owned RN components, mock data, Home/File Detail/Ask AI/Settings/Preview routes, and local handoff docs. | `npm run typecheck` passed. `npm run web -- --port 8088` served `http://localhost:8088`. Playwright via local Chrome opened `/`, `/file/weekly-growth-0709`, `/ask-ai`, `/settings`, `/preview` and captured screenshots under `/tmp/memora-expo-screens`. | Start W2 visual review iteration, then W3 native bridge design shell. |
| 2026-07-09 | In progress | Codex | Added async `MemoraNative` facade consumption through `useAudioFiles` / `useAudioFile`, plus loading/empty/error state components. Home and File Detail no longer read mock arrays directly. | `npm run typecheck` passed. Playwright via local Chrome re-opened all initial routes after facade wiring. | Replace the mock facade with a real Expo native module shell when Dev Client work starts. |
| 2026-07-09 | In progress | Codex | Added typed native bridge contract DTOs, mock transcription event stream, Transcript progress card, `expo-dev-client`, bridge contract docs, and preview routes for empty/not-found states. | `npm run typecheck` passed. Playwright via local Chrome verified Transcript progress reaches 40% after start, plus `/preview`, `/file/empty-transcript`, `/file/not-found`. `npm ls expo-dev-client --depth=0` shows `expo-dev-client@57.0.5`. | Generate native folders and implement the first iOS `MemoraNative` Expo Module shell. |
| 2026-07-09 | In progress | Codex | Generated iOS native project, added local Expo Module `MemoraNative`, wired Swift sample bridge methods/events, installed pods, and proved the Dev Client/native build path without touching existing SwiftUI/STT core. | `npm run prebuild -- --platform ios` passed. `npx expo-modules-autolinking resolve --platform ios --json` detected `MemoraNative`. `cd ios && pod install` installed `MemoraNative (1.0.0)`. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Replace native sample DTOs with read-only adapters to existing Swift services, keeping adapters outside protected STT core. |
| 2026-07-09 | In progress | Codex | Updated RN `MemoraNative` facade to prefer the real iOS Expo Module when available, keep web on the mock path, and added native sample transcription progress events. | `npm run typecheck` passed. Playwright verified web transcript progress still reaches `40%` with `チャンクを処理中です`. Incremental `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Run on an actual simulator with `npm run ios` and verify the file list shows `Native bridge sample`, then replace sample DTOs with read-only native adapters. |
| 2026-07-09 | In progress | Codex | Added `MemoraAudioFileDTO` and `MemoraAudioFileReading` in the local Expo module, routed `listAudioFiles`/`getAudioFile` through the reader boundary, added `getBridgeInfo`, and exposed Bridge diagnostics in RN Settings. | `npm run typecheck` passed. `cd ios && pod install` passed after adding the new Swift file. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified `/settings` shows Bridge and mock source on web. | Resolve local CoreSimulator device creation permission issue, run/inspect iOS Dev Client UI, then replace `MemoraSampleAudioFileReader` with a read-only adapter connected to existing SwiftData or repository surfaces without changing protected STT core. |
| 2026-07-09 | In progress | Codex | Promoted the audio-file DTO/reader boundary to public Swift API and added `MemoraNativeAudioFileReaderRegistry`, so the generated host app target can inject a real SwiftData/repository reader later without coupling the Expo module to app-target models. | `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Add host-app startup injection once the RN target owns a stable SwiftData `ModelContainer`; keep the default sample reader until live simulator verification is unblocked. |
| 2026-07-09 | In progress | Codex | Added `loadSettings`/`saveSettings` to the local native module, module TS types, web fallback, and RN facade; Settings now renders through the facade instead of importing mock settings directly. | `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified `/settings` shows settings, Bridge, and Gemini provider on web. | Replace in-memory settings with a native settings/keychain adapter after deciding which existing Swift settings service is the source of truth. |
| 2026-07-09 | In progress | Codex | Added typed Swift settings boundary: `MemoraSettingsDTO`, `MemoraSettingsReadingWriting`, `MemoraNativeSettingsRegistry`, and a default memory store. `loadSettings`/`saveSettings` now route through the registry, and `getBridgeInfo()` reports `settingsSource`, so a host-app adapter can replace the sample store without moving secrets into React Native. | `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified `/settings` shows settings, Bridge, Settings source, and Gemini provider on web. | Inject a real settings/keychain adapter from the host app target and keep API keys/native secrets out of RN state. |
| 2026-07-09 | In progress | Codex | Replaced the default memory-only settings store with `MemoraUserDefaultsSettingsStore` for non-secret iOS settings, added web `localStorage` fallback persistence, and updated Settings Bridge source typing to include `userdefaults`. | `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified `/settings` and `localStorage` fallback reload. | Continue toward host-app settings/keychain adapter injection only after identifying the existing Swift settings source of truth. |
| 2026-07-09 | In progress | Codex | Added interactive RN Settings controls for transcription mode, summary provider, and SpeechAnalyzer. Controls call `MemoraNative.saveSettings`, so web persists through `localStorage` fallback and iOS persists through the native settings store. | `npm run typecheck` passed. Playwright clicked API/Local provider controls, reloaded `/settings`, and confirmed persisted values plus Settings source. | Add native host-app settings/keychain adapter once the existing source of truth is identified; keep secrets out of RN. |
| 2026-07-09 | In progress | Codex | Added native bridge shell methods for `startRecording`, `stopRecording`, and `importAudio`, plus TypeScript/web wrappers and RN facade native preference. These return placeholder DTOs and do not start AVFoundation or modify existing recording/STT services. | `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Replace placeholder recording/import bridge with adapter calls to existing Swift recording/import services when the native service boundary is confirmed. |
| 2026-07-09 | In progress | Codex | Added a public recording/import registry boundary: `MemoraRecordingSessionDTO`, `MemoraRecordingImportHandling`, `MemoraNativeRecordingImportRegistry`, and `MemoraSampleRecordingImportHandler`. `getBridgeInfo()` now reports `recordingSource`, and Settings shows it in Bridge diagnostics. | `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified `/settings` shows `Recording source`, `Settings source`, and Bridge. | Add a host-app adapter that owns `AudioRecorder`, `AudioFileImportService`, and repository/SwiftData context, then assign `MemoraNativeRecordingImportRegistry.handler` during RN app startup. |
| 2026-07-09 | In progress | Codex | Wired Home recording/import buttons to `MemoraNative.startRecording`, `stopRecording`, and `importAudio`, added bridge status output, and added accessibility labels for stable browser/UI testing. | `npm run typecheck` passed. Playwright clicked Home `録音を開始`, `録音を停止`, and `音声を取り込み`, confirming recording session, returned file DTO, and `import-preview.m4a`. | Replace the preview URI/button behavior with a real document picker or native import picker after the native adapter returns real files. |
| 2026-07-09 | In progress | Codex | Replaced the default recording/import registry handler with `MemoraNativeFileRecordingImportHandler`. It records `.m4a` files with AVFoundation under app Documents, imports selected file URIs into app Documents, returns `AudioFileDTO`, reports `recordingSource: native-file`, and adds microphone usage strings. Existing SwiftUI, STT core, and `bot-server` were not modified. | `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Persist returned DTOs through a host-app SwiftData/repository adapter, then replace the audio list reader with the real repository source. |
| 2026-07-09 | In progress | Codex | Installed `expo-document-picker` and changed Home import to open a real audio/video picker, then pass the selected asset URI into `MemoraNative.importAudio`. The old fixed `file:///Memora/import-preview.m4a` preview path is no longer used by the UI. | `npm run typecheck` passed. `cd ios && pod install` installed `ExpoDocumentPicker (57.0.0)`. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified Home recording start/stop, import button presence, and Settings bridge diagnostics on web. | Run a live iOS Dev Client import/recording pass after the local CoreSimulator storage permission issue is fixed, then connect native file results to SwiftData/repository persistence. |
| 2026-07-09 | In progress | Codex | Added `MemoraNativeFileAudioFileReader` and a JSON metadata store for native-file recordings/imports. `listAudioFiles`/`getAudioFile` now read local native-file metadata first and fall back to the sample file only when no local records exist. Bridge `audioFileSource` can now report `native-files`. | `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified Home recording start/stop and Settings Bridge on web. | Live-test on iOS Dev Client after CoreSimulator is writable; then replace local JSON metadata with host-app SwiftData/repository persistence. |
| 2026-07-09 | In progress | Codex | Updated `useAudioFiles` and Home so recording/import results are optimistically inserted into the visible list, then silently refreshed from the bridge. The web fallback now keeps generated files in memory so Expo/Web review shows the same list-update behavior as native-file metadata. | `npm run typecheck` passed. Playwright clicked Home recording start/stop and confirmed the generated `.m4a` appears in the recent files list. | Apply the same refresh pattern to delete/rename/move once those bridge methods exist; live-test native metadata refresh in iOS Dev Client after simulator storage is fixed. |
| 2026-07-09 | In progress | Codex | Added Home refresh ergonomics: `Screen` can accept a native `RefreshControl`, Home refreshes silently on focus, supports pull-to-refresh, and exposes an icon refresh button in the Recent Files header. | `npm run typecheck` passed. Playwright clicked the refresh button, then recorded/stopped and confirmed the generated `.m4a` remained visible in the recent files list. | Use the same refresh contract for future rename/delete/move bridge methods and verify pull-to-refresh in the iOS Dev Client when simulator access is fixed. |
| 2026-07-09 | In progress | Codex | Added `renameAudioFile` and `deleteAudioFile` bridge methods. Native metadata delete removes the JSON entry and stored file; rename updates the stored title. RN Home shows a trash action only for safe bridge-generated/native-file records, removes deleted files from state, and silently refreshes from the bridge. | `npm run typecheck` passed. Playwright generated a web fallback recording, verified the delete control, and confirmed the visible file count decreased after delete. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Wire rename UI in File Detail/Home, then move create/rename/delete persistence from local JSON metadata into the existing SwiftData/repository adapter. |
| 2026-07-09 | In progress | Codex | Wired `renameAudioFile` into File Detail with inline title editing for safe bridge-generated/native-file records, and split `AudioFileCard` open/delete press targets to avoid nested button behavior on web. | `npm run typecheck` passed. Playwright with local Google Chrome verified recording generation, opening the generated file, editing/saving title, returning to Home, and seeing the renamed title. It also confirmed no nested button warning text was visible. | Move rename/delete/create persistence behind a host-app SwiftData/repository adapter and run the same flow in iOS Dev Client after CoreSimulator is writable. |
| 2026-07-09 | In progress | Codex | Added `MemoraAudioFileMutating` and `MemoraNativeAudioFileMutationRegistry`, then routed native create/rename/delete through the mutation registry instead of direct JSON metadata calls. Settings Bridge now shows `Mutation source` separately from read source. | `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified `/settings` shows `Mutation source` on web. | Implement host-app SwiftData/repository mutator and reader injection, keeping existing repository/STT files untouched unless explicitly approved. |
| 2026-07-09 | In progress | Codex | Added RN iOS startup bootstrap in `AppDelegate` that explicitly assigns the current native-file reader, mutator, recording/import handler, and UserDefaults settings store to the `MemoraNative` registries. This is the concrete injection point for the future SwiftData/repository adapters. | `npm run typecheck` passed. First `xcodebuild` caught Swift import access mismatch; changed `import MemoraNative` to `internal import MemoraNative`. Re-run `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Replace the bootstrap defaults with SwiftData/repository adapters once the RN target owns or receives a stable `ModelContainer`. |
| 2026-07-09 | In progress | Codex | Split the RN iOS bootstrap into `MemoraNativeBridgeBootstrap.swift`, added it to the Xcode target, and simplified `AppDelegate` to call `MemoraNativeBridgeBootstrap.configureDefaults()`. Added generic `MemoraNativeBridgeBootstrap.configure(...)` so future SwiftData/repository adapters can be injected from one startup point. `getBridgeInfo()` now derives `isRealDataConnected` from registry sources instead of hardcoding `false`. | `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright verified `/settings` still shows Bridge and `Mutation source` on web. | Implement a SwiftData bootstrap variant that calls `MemoraNativeBridgeBootstrap.configure(...)` with `swiftdata` reader/mutator sources when a `ModelContainer` is available. |
| 2026-07-09 | In progress | Codex | Inspected the existing SwiftData `AudioFile` and `AudioFileRepository` boundary plus the generated RN Xcode target membership. The repository shape is suitable for a future adapter, but `MemoraRN` currently compiles only RN host Swift files and pods, not existing `Memora/Core` model/repository files. | `rg`/`sed` inspection completed. `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Decide how `MemoraRN` will access existing SwiftData types: share selected `Memora/Core` files into the RN target, extract a small shared Swift package/framework, or expose data through a native app service layer. Do not import app-target internals directly into the Expo module. |
| 2026-07-09 | In progress | Codex | Upgraded the RN Ask AI screen from static mock bubbles to an interactive scoped query surface. It now supports file/project/global scope switching, scoped message history, empty state, text input, disabled send state, loading state, generated answer, and source pills. | `npm run typecheck` passed. Headless local Google Chrome via CDP verified `/ask-ai`: global empty state, question entry, send, generated global answer, source pill, and project-scope history. | Add a native/query facade for Ask AI after the retrieval/search boundary is selected; until then keep the UI on deterministic mock answers for review. |
| 2026-07-09 | In progress | Codex | Added `queryKnowledge` DTOs and facade plumbing for Ask AI. RN now calls `MemoraNative.queryKnowledge`; the local Expo module has `MemoraKnowledgeQuerying`, `MemoraNativeKnowledgeQueryRegistry`, and a safe sample implementation. Settings Bridge now reports `Knowledge source`. | `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Headless local Google Chrome verified `/ask-ai` query flow and `/settings` Knowledge source. | Replace `MemoraSampleKnowledgeQuery` with a host-app adapter only after selecting the retrieval/query source of truth. Do not connect AI providers or `KnowledgeQueryService` directly from the Expo module. |
| 2026-07-10 | In progress | Codex | Added `SummaryRequestDTO`, `MemoraSummaryGenerating`, `MemoraNativeSummaryRegistry`, native `generateSummary`, and `summarySource` diagnostics. RN `MemoraNative.generateSummary` now prefers the native module and falls back to the web/mock implementation. | `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. | Connect a host-app summary adapter after selecting the source of truth and provider ownership; keep `AIService`, provider SDKs, and Keychain out of the local Expo module. |
| 2026-07-10 | In progress | Codex | Connected File Detail Summary actions to `MemoraNative.generateSummary`. The RN screen now shows generating state, error state, and reflects the returned summary DTO/status. | `npm run typecheck` passed. Web server responded at `http://localhost:8088/file/weekly-growth-0709`; live browser interaction could not be reattached because the existing Chrome CDP endpoint was unavailable in this shell. | Run the Summary tab interaction in Chrome/Expo web, then wire the selected host-app summary adapter. |
| 2026-07-10 | In progress | Codex | Connected File Detail summary generation to the persisted RN settings provider and added provider/timestamp metadata after a successful response. | `npm run typecheck` passed. Web returned HTTP 200 for `/file/weekly-growth-0709` and `/ask-ai`. `git diff --check` passed. | Verify the click flow in a browser session, then begin the shared Swift package skeleton in a separate native-data batch. |
| 2026-07-10 | In progress | Codex | Expanded `MemoraSharedData` with `MemoraInMemoryAudioFileStore` and page/update/delete contract tests, while keeping SwiftData models out of the package. | `swift test` passed with 2 tests. Expo `npm run typecheck` passed. Existing `Memora` iOS Simulator build passed with `BUILD SUCCEEDED`. `git diff --check` passed. | Add the first real repository mapper only after deciding how the shared package will own or receive the existing `ModelContainer`. |
| 2026-07-10 | In progress | Codex | Added `MemoraSharedAudioFileStoreAdapter` in the existing Memora target. It maps `AudioFileRepositoryProtocol` to `MemoraSharedAudioFileStore` and exposes `sourceDescription = "swiftdata"` without moving the SwiftData model graph. | `xcodebuild -project Memora.xcodeproj -scheme Memora -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. `swift test` passed with 2 tests. Expo `npm run typecheck` passed. | Add focused adapter tests, then solve how the RN host target receives the same repository/model context. |
| 2026-07-10 | In progress | Codex | Linked `Packages/MemoraSharedData` into the separate RN Xcode host target and added a compile-time contract probe in `MemoraNativeBridgeBootstrap.swift`. The RN default source remains native-file/sample; no false SwiftData status is reported. | First build caught an iOS deployment mismatch and was corrected by setting the package minimum to SwiftPM `.iOS(.v16)`. Final RN `xcodebuild` passed with `BUILD SUCCEEDED`; existing Memora `xcodebuild` passed with `BUILD SUCCEEDED`; `swift test` passed with 2 tests; Expo typecheck passed. | Inject the real repository/model context into the RN host adapter. The package link is ready, but the separate RN target still does not compile the existing app model graph. |
| 2026-07-10 | In progress | Codex | Added `persistenceScope` to bridge diagnostics. RN now explicitly reports `app-sandbox`/`mock` until a verified shared App Group or SwiftData boundary exists. | RN iOS Simulator build passed with `BUILD SUCCEEDED`; Expo `npm run typecheck` passed; `swift test` passed with 2 tests; `git diff --check` passed. | Decide App Group migration versus same-target RN embedding before enabling shared SwiftData. |
| 2026-07-10 | In progress | Codex | Added `MemoraSharedStoreLocation` to centralize future App Group store URL resolution and a stable path test. No entitlements or persistent store paths were changed. | RN iOS build passed with `BUILD SUCCEEDED`; Expo `npm run typecheck` passed; `swift test` passed with 3 tests; `git diff --check` passed. | Choose a new App Group and design store migration/rollback before enabling shared persistence. |
| 2026-07-10 | In progress | Codex | Added overwrite-protected `MemoraStoreMigration.copyStore(from:to:)` for the SQLite store and `-shm`/`-wal` sidecars, with temporary-directory coverage. | RN iOS build passed with `BUILD SUCCEEDED`; existing Memora iOS build passed with `BUILD SUCCEEDED`; Expo `npm run typecheck` passed; `swift test` passed with 4 tests; `git diff --check` passed. | Add a closed-store migration command/host hook only after App Group ownership and rollback policy are approved. |
| 2026-07-10 | In progress | Codex | Added `MemoraSharedAudioFileStoreAdapterTests` covering `AudioFile` to shared-record field mapping, existing-record updates, new-record creation, and ID-based deletion. | `xcodebuild -project Memora.xcodeproj -scheme Memora -destination 'generic/platform=iOS Simulator' build` passed; RN `xcodebuild` passed; `swift test` passed with 4 tests; Expo `npm run typecheck` passed; `git diff --check` passed. `build-for-testing` reached the test target but is currently blocked by the pre-existing `CreateProjectViewModelTests` reference to a missing `CreateProjectViewModel`; concrete simulator execution is also unavailable. | Keep the adapter test in place, repair or restore the unrelated existing test-target source separately, then run `MemoraTests` on a concrete simulator before choosing the App Group identifier and migration/rollback owner. |
| 2026-07-10 | In progress | Codex | Hardened `MemoraStoreMigration.copyStore(from:to:)` so all destination sidecars are checked before any file is copied. Added missing-source and destination-sidecar conflict coverage. | `swift test` passed with 6 tests. Expo `npm run typecheck` passed. `git diff --check` passed. | Keep migration utility unwired until the SwiftData store is closed and App Group ownership, backup, rollback, and release sequencing are approved. |
| 2026-07-10 | In progress | Codex | Tightened RN Bridge diagnostics so `isRealDataConnected` and `persistenceScope = shared-swiftdata` require both the reader and mutator to report `swiftdata`. | RN iOS build passed; Expo `npm run typecheck` passed; `git diff --check` passed. | Inject both host-side SwiftData adapters together only after the shared store/context boundary is verified. |
| 2026-07-10 | In progress | Codex | Restored the missing `CreateProjectViewModel` using the existing `ProjectsViewModel` Observation pattern and the behavior specified by `CreateProjectViewModelTests`. | `xcodebuild ... build-for-testing` passed with `TEST BUILD SUCCEEDED`; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed. | Run the complete `MemoraTests` suite on a concrete simulator once CoreSimulator exposes a device, then continue the shared SwiftData host injection. |
| 2026-07-10 | In progress | Codex | Updated the existing SwiftUI `MemoraApp` to resolve its unchanged `Application Support/Memora/Memora.store` path through `MemoraSharedStoreLocation`, making the shared package the single path contract without moving data. | Existing Memora iOS build passed; RN iOS build passed; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed. | Add an explicit host-owned `ModelContainer` injection seam for RN, then validate both targets against a deliberately selected shared store strategy. |
| 2026-07-10 | In progress | Codex | Added `MemoraSharedStoreBridgeAdapter` to the RN host target. It maps any host-provided `MemoraSharedAudioFileStore` into the Expo reader/mutator DTO protocols and provides `configureSharedAudioStore(...)` without changing the default native-file path. | RN iOS build passed; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed. | Provide the adapter with a host-owned SwiftData repository only after both targets agree on `ModelContainer` and store ownership; keep `configureDefaults()` active until then. |
| 2026-07-10 | In progress | Codex | Added `MemoraSharedStoreHostFactory` in the existing SwiftUI target. It creates the shared audio-file adapter from a host-owned `ModelContainer` and `AudioFileRepository` without changing startup or RN defaults. | Memora iOS build passed; RN iOS build passed; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed. | Decide the cross-target transport for this host-created adapter, then connect it to RN only after shared store ownership and migration sequencing are approved. |
| 2026-07-10 | In progress | Codex | Hardened the RN shared-store bridge adapter to throw explicit errors for invalid audio UUIDs and empty rename titles instead of silently returning or creating fallback IDs. | RN iOS build passed; Expo `npm run typecheck` passed; `git diff --check` passed. | Add focused host-adapter tests when a RN host test target is introduced, then complete the cross-target store ownership design. |
| 2026-07-10 | In progress | Codex | Added `sourceDescription` to `MemoraSharedAudioFileStore` so RN diagnostics preserve the real source of injected stores; the in-memory implementation now reports `mock` instead of being mistaken for SwiftData. | RN iOS build passed; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed. | Pass only a verified SwiftData-backed store to `configureSharedAudioStore(...)` before enabling shared persistence. |
| 2026-07-10 | In progress | Codex | Added the `MemoraRNTests` host test target and three adapter tests for DTO mapping/source preservation, shared-store rename/delete, and explicit invalid mutation errors. | RN workspace `build-for-testing` passed with `TEST BUILD SUCCEEDED`; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed. Runtime execution still needs a concrete simulator. | Run `MemoraRNTests` on a usable simulator, then connect a verified SwiftData-backed store through `configureSharedAudioStore(...)`. |
| 2026-07-10 | In progress | Codex | Started the Home visual-parity pass against SwiftUI V6: replaced the migration scaffold hero with the `全ファイル` layout, white canvas, V6 black/red tokens, compact connection/actions row, filter tabs, and thin file rows. Preserved recording/import/delete/detail behavior. | Expo `npm run typecheck` passed; Metro re-bundled the physical-device client; `git diff --check` passed. Repository has no `lint` script. | Continue matching V6 Home spacing/FAB behavior, then align File Detail, Ask AI, and Settings screen shells. |
| 2026-07-10 | In progress | Codex | Aligned the RN File Detail shell with V6: white header with back/share/more affordances, title/date metadata, status row, underline tabs, flatter content panels, and a file-question bar. Existing rename, summary generation, transcription task, memo, and detail routing remain intact. | Expo `npm run typecheck` passed; Metro re-bundled the iOS client; `git diff --check` passed. | Replace no-op share/more actions with the native export/action contract, then align Ask AI and Settings shells. |
| 2026-07-10 | In progress | Codex | Aligned the RN Ask AI shell with the V6 visual language: compact underline scope tabs, black user messages, flatter assistant messages, subdued source chips, and a bordered white composer. Scope-specific histories and `queryKnowledge` behavior remain unchanged. | Expo `npm run typecheck` passed; Metro received the updated iOS bundle request; `git diff --check` passed. | Align Settings and bottom action/FAB behavior, then inspect all screens on the physical iPhone. |
| 2026-07-10 | In progress | Codex | Aligned the RN Settings shell with V6 grouped settings rows: removed explanatory hero/card copy, made settings sections denser, changed selected controls to black, and kept Bridge diagnostics as compact status rows. Settings DTO persistence and source diagnostics remain unchanged. | Expo `npm run typecheck` passed; Metro received the updated iOS bundle request; `git diff --check` passed. | Align Home bottom FAB/action behavior, then inspect all four screens on the physical iPhone and capture remaining spacing differences. |
| 2026-07-10 | In progress | Codex | Added a Home-only fixed bottom FAB dock to the shared RN screen shell. The FAB opens functional `録音` and `取り込み` actions while preserving the existing native bridge handlers; the connection row is now informational like V6. | Expo `npm run typecheck` passed; `git diff --check` passed; Metro remains connected to the physical-device client. | Inspect the physical iPhone for FAB/tab-bar overlap and tune spacing, then run the four-screen visual review. |
| 2026-07-10 | In progress | Codex | Connected File Detail share and more actions: share now uses the iOS `Share` sheet with title/summary content, and more opens the existing rename path for renameable bridge files. No new data ownership was introduced. | Expo `npm run typecheck` passed; Metro received the updated iOS bundle request; `git diff --check` passed. | Validate the share sheet and rename action on the physical iPhone, then continue the visual review. |
| 2026-07-10 | In progress | Codex | Ran the validation tracks in parallel for the RN UI, native host, shared Swift package, and handoff document. | Expo typecheck passed; Expo web export passed with 891 modules; RN workspace `build-for-testing` passed with `TEST BUILD SUCCEEDED`; `swift test` passed with 6 tests; `git diff --check` passed. | Validate UI interactions on the physical iPhone, then decide the native export/settings boundary and shared SwiftData ownership separately. |
| 2026-07-10 | In progress | Claude | Rebuilt/installed/relaunched the RN Dev Client build on the paired physical `Ken's iPhone` and confirmed the JS bundle actually connected (not just a native launch). Re-ran the full validation suite. Diagnosed the CoreSimulator device-creation blocker to its precise root cause and partially fixed it, but simulator creation is still not usable. | `xcodebuild ... -destination 'id=9A1B4213-7A1A-5663-8456-1FBEE0E724C8' -allowProvisioningUpdates build` passed with `BUILD SUCCEEDED`; `devicectl device install/launch` succeeded; confirmed 5 established TCP sockets from the phone (192.168.86.130) to Metro on port 8089 immediately after launch (proof of JS bundle load, not just native process alive); `npm run typecheck` passed; `xcodebuild ... -destination 'generic/platform=iOS Simulator' build-for-testing` passed with `TEST BUILD SUCCEEDED`; `Packages/MemoraSharedData` `swift test` passed with 6 tests; `npx expo export --platform web` passed; `git diff --check` clean. | Do NOT attempt visual UI verification claims without a working screenshot path. See blocker note below before spending more time on CoreSimulator. |
| 2026-07-10 | In progress | Claude | Fully resolved the CoreSimulator Full Disk Access blocker (both `SimulatorTrampoline.xpc` and `CoreSimulatorService.xpc` needed direct drag-and-drop FDA grants, not just Xcode.app), created and booted a working simulator on the external volume, built an automated screenshot+tap QA loop via `simctl io screenshot` + `osascript`/System Events + `cliclick`, and used it to actually view and interact with Home, File Detail, Ask AI, and Settings for the first time this migration. | Real screenshots captured and inspected for all 4 screens; FAB expand/collapse confirmed no tab-bar overlap; Ask AI scope switching confirmed working across all 3 scopes; found and documented a real bug (File Detail double header). `git diff --check` clean (docs only, no source changes this session). | Fix the File Detail double-header bug. Continue the V6 spacing/polish pass using the now-working screenshot loop. Fix the scroll-gesture automation for deeper-content verification. |
| 2026-07-10 | In progress | Claude | Fixed the File Detail double-header bug by setting `headerShown: false` on the `file/[id]` route in `apps/mobile-expo/app/_layout.tsx`, matching the pattern already used for the `(tabs)` group. | `npm run typecheck` passed. Verified visually via the simulator screenshot+tap loop: File Detail now shows exactly one header, and the back button still navigates to Home correctly. `apps/mobile-expo` is untracked in git so `git diff --check` shows nothing for this change by design; confirmed via `git status --short`. | Continue the V6 spacing/polish pass (Home, File Detail, Ask AI, Settings) using the working screenshot loop; resolve scroll-gesture automation if deeper content needs review. |
| 2026-07-10 | In progress | Claude | Read V6 SwiftUI source directly (not just screenshots) to fix File Detail's duplicate-title bug and token mismatches (icon touch targets, title weight/tracking/line limit, tab spacing), and rewrote Ask AI's message rendering from rounded chat bubbles to V6's actual plain-document style (no bubble backgrounds; V6 source explicitly states messages are "not rounded chat bubbles"). Deferred the larger Settings information-architecture gap to a separate decision per user direction. | `npm run typecheck` passed after each change. Verified visually via the simulator screenshot+tap loop for both screens. `git diff --check` clean (untracked app dir, confirmed via `git status --short`). | Home connection-row/title ordering difference vs V6 (found, not fixed — needs a `Screen` header-composition decision). Settings IA decision. Scroll-gesture automation fix. |
| 2026-07-10 | Done (session close) | Claude | Fixed the `cliclick` scroll-gesture automation (needed a leading `m:` move plus real waits between drag steps) and used it to scroll through and verify the entire Settings screen, including the previously-unverified Bridge diagnostics content below `Omi preview`. Ran the full validation suite as a final session close-out. | `npm run typecheck` passed; `Packages/MemoraSharedData` `swift test` passed with 6 tests; RN workspace `build-for-testing` on `generic/platform=iOS Simulator` passed with `TEST BUILD SUCCEEDED`; `git diff --check` clean. | Home header-ordering decision and Settings IA decision remain open, both explicitly deferred pending user input — do not guess at either without asking first. |
| 2026-07-10 | Done (session close) | Claude | User explicitly said to proceed, so implemented the Home connection-row/title reorder to match V6 (added `Screen`'s optional `topRow` slot, moved Home's search/settings icons alongside the connection row above the title). Settings IA remains explicitly deferred — not touched. | `npm run typecheck` passed; verified visually via the simulator screenshot+tap loop, including confirming search/settings icon navigation still works from the relocated position; `git diff --check` clean. | Only the Settings IA decision remains open from this session. Next session can pick that up or move to other independent workstreams. |
| 2026-07-10 | Done (session close) | Claude | User was asked and explicitly chose to add V6's Settings information architecture (Account/Device/Storage/Notifications/Integrations/AI model/Delete data/Logout) with mock/placeholder data, keeping the existing Bridge diagnostics content below it rather than replacing it. Implemented all 8 groups matching V6's exact row/badge/toggle styling; every interactive row shows a "not yet connected" alert rather than pretending to work. | `npm run typecheck` passed; verified visually via the simulator screenshot+tap loop, including tapping "データを削除" and confirming the alert text; `git diff --check` clean. | No open items remain from this session's V6 review. Resume from top-level W4/W5 workstreams or start a new screen's V6 comparison pass. |
| 2026-07-10 | Found, not fixed | Claude | Continued the V6 review into unvisited states of existing screens per user request. Home's プロジェクト/ライフログ empty states are fine. Found that File Detail's Transcript and Memo tabs are missing real functionality present in V6 (audio playback controls with seek/speed; editable memo text + photo attachment) — these are native-bridge feature gaps, not styling gaps, so nothing was built without a scope decision. | Read `TranscriptTab.swift` and `MemoTab.swift` directly; verified the RN gap via the simulator screenshot+tap loop. | Awaiting user decision: build as real native-bridge features, build as explicitly-disabled V6-styled placeholders, or defer. |
| 2026-07-10 | Done (Playback verified, Memo unverified, test-target build regressed) | Claude | User chose real native-bridge implementation. Built a full `AVAudioPlayer`-backed playback bridge (load/play/pause/seek/setRate/getStatus) and a JSON-backed memo/photo-attachment bridge (draft text + `expo-image-picker`-based photo attachments), following the existing recording/import bridge's registry pattern exactly. Wired both into new File Detail UI (`PlayerBar` component, editable Memo tab). | `npm run typecheck` passed; `xcodebuild build` (app target, not tests) for the simulator passed repeatedly and reliably. Live-verified playback end-to-end on a real ~2m49s recording (PlayerBar showed the true `02:49` duration, proving it reads real audio, not a fallback simulation). Memo tab compiles but could not be screenshot-verified — Simulator window became inaccessible to macOS Accessibility mid-session (`count of windows` stuck at 0), user chose to skip re-verifying it. `swift test` passed with 6 tests. **`build-for-testing` for `MemoraRNTests` now fails** with `cannot load underlying module for 'EXConstants'` in a pre-existing test file — reproduced 3 times (plain retry, module cache wipe, full DerivedData wipe); likely triggered by this session's `pod install` after adding `expo-image-picker`, not yet root-caused. | Fix the `build-for-testing`/EXConstants regression (open in Xcode.app for full diagnostics). Recover the Simulator window and visually confirm the Memo tab. |
| 2026-07-11 | In progress | Codex | Began the Claude V6-gap execution backlog: replaced the system tab bar and Home-only red FAB with the V6 4-tab floating black dock and global 3-action FAB; added a mock-backed Tasks route; aligned non-Home titles to 30pt and added V6 tokens. | `npm run typecheck`, `npx expo export --platform web`, `pod install`, and the RN app-target `xcodebuild ... build` passed. The first simulator screenshot found an ExpoBlur ViewManager runtime error; the dependency was removed and the dock now uses the V6 dark surface/tint/stroke directly. Final post-removal UI re-entry could not be captured because manual Dev Client reload returned to SpringBoard. | Capture the rebuilt Dev Client UI again, then implement the recording full-screen modal and generation-progress flow before Dynamic Island. |
| 2026-07-11 | In progress | Codex | Added the V6 recording and generation flow: the common capture provider opens a full-screen recording UI, connects native pause/resume/discard, preserves the session when minimized, then runs the existing transcription and summary bridge calls behind generation progress. Also completed immediate V6 copy/order fixes for Ask and File Detail tabs. | Expo typecheck and web export passed; RN app-target build passed. Simulator verified the floating dock/FAB, recording screen, native pause/resume, stop-to-generation completion, task completion toggle, Ask scope order/default, and fixed Ask composer. | Add Dynamic Island/notification state, then tackle the File Detail and Home information-architecture differences. |
| 2026-07-11 | In progress | Codex | Added active-only Dynamic Island states for minimized recording, background generation, and completion snackbar. Refactored recording/generation into one full-screen Modal after finding a React Native two-Modal transition race. | Expo typecheck and web export passed; RN app-target build passed. Simulator verified minimized live-recording pill and reopening it, then verified stop opens `音声を解析中…` directly after the single-Modal refactor. | Implement Home file-row/filter sheet and File Detail information architecture; keep test-target EXConstants repair as separate QA work. |
| 2026-07-11 | In progress | Codex | Replaced Home's filter pills and card rows with the V6 title-triggered filter sheet, `今日` / `今週` / `以前` groups, flat file rows, and a V6 file-operation sheet. | `npm run typecheck`, `npx expo export --platform web`, and the RN app-target `xcodebuild ... build` passed. Simulator screenshots confirmed the grouped flat row, filter selection sheet, and title/move/delete action sheet. | Continue the V6 File Detail information architecture pass; keep actual project move and retry queue wiring as separate bridge work. |
| 2026-07-11 | In progress | Codex | Moved File Detail to V6's icon-only top row, single-line title/date header, tab-first content, fixed Ask bar, and bottom-sheet file actions. | `npm run typecheck`, `npx expo export --platform web`, and RN app-target `xcodebuild ... build` passed. Simulator screenshot confirmed the fixed Ask bar and V6 header order; long native filenames are now explicitly single-line truncated. | Implement the remaining P1 onboarding/login/paywall route flow, then do a full screen-by-screen V6 comparison. |
| 2026-07-11 | In progress | Codex | Added the V6 auth review route: 3-step onboarding, provider/email/code login states, and Free/Pro paywall selection. | `npm run typecheck`, `npx expo export --platform web`, and RN app-target `xcodebuild ... build` passed. Simulator confirmed onboarding, login provider choices, and email input state; `/auth` is available from Preview Index. | Implement real auth/StoreKit only after their ownership and backend contracts are selected; meanwhile run the remaining V6 gap audit. |
| 2026-07-11 | In progress | Codex | Completed the remaining Ask visual shell: new-chat control, scope caption, V6 suggestion prompts, attachment affordance, response actions, and 3-dot loading state. | `npm run typecheck` and `npx expo export --platform web` passed. Simulator screenshot confirmed the global Ask empty/suggestion state, fixed composer, and tab selection. | Continue P2 with File Detail summary/transcript/memo content or Home project/lifelog data; both need bounded data/bridge decisions. |
| 2026-07-11 | In progress | Codex | Completed the remaining V6 review-shell work: Home projects/lifelogs, full-screen filter overlay, interaction feedback, File Detail summary/transcript/memo layout, export choice sheet, and guarded delete confirmation. | `npm run typecheck`, `npx expo export --platform web`, and RN app-target `xcodebuild ... build` passed. Simulator verified filter overlay, project grid, summary layout, and export sheet. | Real auth/payments, file project-move/retry, Ask attachments/task creation, SwiftData migration, and EXConstants test-target repair remain separate feature/QA work. |
| 2026-07-11 | Superseded (pill removed) | Claude | Investigated the Ask in-app pill from the prior handoff. Installed the fresh `/tmp/memora-ask-pill-fresh` Dev Client build (it had finished, contrary to the handoff assumption it was still running), and found the pill rendered fully invisible (pure white pixels, confirmed via pixel sampling, not just a hunch). Root cause: Reanimated's `FadeInDown` entering animation was stuck because the project has no `babel.config.js`/`babel-preset-expo` at all, so the Worklets babel plugin never transforms the code. Tried adding `babel-preset-expo@57.0.2` + `babel.config.js` as a fix; this instead triggered a hard native crash in `ExpoModulesWorklets` (`EXC_BREAKPOINT`/`SIGTRAP`) on every launch, so the change was reverted (`babel.config.js` deleted, `babel-preset-expo` uninstalled) to restore the prior, non-crashing state. Separately hit a `Simulator`/CoreSimulator instability (`could not bind to session`, screen-surface timeouts) consistent with the known HIKSEMI external-volume flakiness noted earlier in this doc; recovered by killing `CoreSimulatorService` and having the user manually reboot the simulator. After that clean reboot, with **no code change from the reverted state**, the pill rendered correctly (black pill, white "Ask 質問する" text, sparkles icon) — so the original invisible-pill bug was actually a stale/corrupt Metro or Simulator cache state, not a real code defect, and no source fix was needed or kept. | Confirmed via `sips`/PIL pixel sampling that the pill area was pure white before the reboot and rendered correctly (dark `colors.ink` pixels with the expected text) after. Could not automate a tap-through verification: host-level `cliclick`/`osascript` clicks at computed window-content coordinates produced no visible state change across several calibration attempts, and this is judged to be a click-coordinate-calibration/tooling gap in this headless session, not evidence the tap handler is broken (the `requestAsk()`/`AskIslandPill` code path was read and looks correct). | Manually tap the Ask pill on-device or in an interactive Simulator session to confirm it navigates to the Ask tab. If a future invisible/frozen-animation issue recurs, suspect Metro/Simulator cache state first (`--clear`, Simulator reboot) before assuming a Reanimated/Worklets version or babel config defect. |
| 2026-07-11 | Done | Claude | User feedback: the floating "Ask 質問する" pill under the notch looked cheap ("ダサい") and they asked whether the real hardware Dynamic Island could launch Ask instead. Explained that only ActivityKit Live Activities can render into the physical Dynamic Island cutout (no other public API exists), and the user explicitly ruled out Live Activity due to its battery cost. User then chose the recommended option: remove the floating pill entirely since the dock already has a dedicated Ask tab immediately left of the FAB. | Removed `AskIslandPill`, the `askRequestId`/`requestAsk`/`consumeAskRequest` contract (now-dead since the pill was its only caller), the now-unused `expo-haptics` and `react-native-reanimated` imports in `CaptureFlowProvider.tsx`, related styles, and the `askRequestId`-consuming `useEffect` in `V6FloatingTabBar.tsx` (with its now-unused `useEffect` import). The recording/generation/snackbar Dynamic-Island-shaped pill (timer, progress, completion) is untouched; it now simply renders `null` instead of the Ask pill when idle. | `npm run typecheck` passed. Verified visually via the simulator screenshot loop: the notch-area pill is gone on the idle Home screen, dock's Ask tab is unaffected. | Physical Dynamic Island / Live Activity remains explicitly out of scope (ruled out for battery cost). No dedicated Ask entry point exists besides the dock tab and any FAB action; revisit only if the user asks for a different affordance. |
| 2026-07-12 | Done (bridge foundation) | Codex | Added the non-UI project-move contract across the Expo native module, TypeScript facade, native-file metadata store, and shared-store adapter. `projectId: null` moves a file to Inbox; shared real-data adapters accept UUID project IDs and reject invalid IDs before repository lookup. | `npm run typecheck` passed; `swift test --package-path Packages/MemoraSharedData` passed 6/6; isolated RN `qa:ios:build` passed; `qa:ios:test` passed 3/3 on iPhone 17 Pro / iOS 26.5. | Claude can wire the existing move sheet to `MemoraNative.moveAudioFile` without changing the bridge contract. Retry queue remains the next independent native workstream. |
| 2026-07-12 | Done (retry queue foundation) | Codex | Added a persistent non-UI processing retry queue for transcription and summary failures. It deduplicates by file/operation, stores the latest error, increments attempt count, restores after queue reinitialization, and removes completed work. The queue deliberately does not invoke protected STT/AI services. | `npm run typecheck` and `pod install` passed; isolated RN `qa:ios:build` passed; `qa:ios:test` passed 4/4 on iPhone 17 Pro / iOS 26.5. | Connect failure handlers and a host-owned retry worker in a separate integration batch; UI can consume list/complete methods later without changing this contract. |
| 2026-07-12 | Done (code); keyboard-avoidance visual unverified | Claude | Added built-in `KeyboardAvoidingView` (no native dep, no rebuild) so bottom-anchored inputs lift above the software keyboard: `Screen.tsx` (wraps ScrollView + `footerAccessory`, `behavior='padding'` on iOS, `keyboardShouldPersistTaps='handled'`), `TasksScreen.tsx` add-task sheet, and `FileDetailScreen.tsx` rename dialog. JS-only, no V6 visual conflict. | `npm run typecheck` passed; `npx expo export --platform web` succeeded (1.8MB bundle, no errors). Simulator visual verification of the keyboard lift was **not** obtained: the Simulator tap-automation could not reliably focus the Ask composer input to raise the software keyboard (known automation flakiness, plan §F), so on-device keyboard behavior remains to be eyeballed. | Manually confirm on-device/interactive Simulator that the Ask composer, Tasks add sheet, and File Detail rename input all clear the software keyboard. Consider AuthFlow email input if the same pattern is wanted there. |
| 2026-07-12 | Done (code); visual unverified | Claude | Extended keyboard avoidance to `AuthFlowScreen.tsx`: wrapped the stage content in `KeyboardAvoidingView` so the bottom-pinned primary buttons (`確認コードを送信` / `確認`) stay reachable above the software keyboard on the email/code login stages. Audited all `TextInput` usages and confirmed complete coverage — Ask composer and Memo editor are already inside `Screen`'s KAV, the Tasks/rename sheets have their own, and AuthFlow is now covered. | `npm run typecheck` passed; `npx expo export --platform web` succeeded (no errors). Same automation limitation as above — on-device keyboard lift still needs a manual eyeball. | Manual/interactive keyboard-lift check across Ask composer, Tasks add sheet, File Detail rename, and AuthFlow email/code stages. |
| 2026-07-12 | Done (visually verified) | Claude | V6 fidelity pass on the Ask empty state + minor message-block alignment, comparing `AskAIScreen.tsx` against the `docs/design/source/Memora Redesign v6.dc.html` ASK block (lines 700-771). Empty-state heading changed from a bold 16px ink title to V6's centered 13px/400 muted caption; suggestion boxes lost their trailing arrow + space-between and now use ink text (was muted) as plain rounded boxes. Also aligned assistant-message action text to `textMutedLight`, the block divider to `paleLine`, and the assistant body line-height to 25 (V6 1.7em). | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Visually verified on the `Memora RN Test` simulator via `memora-rn://ask-ai` screenshot: caption is centered/muted, suggestion boxes are arrow-free ink text. **Bonus: this screenshot also confirmed the earlier keyboard-avoidance work — the Ask composer visibly lifts above the software keyboard.** A ~94px gap remains between composer and keyboard (the dock-reserved `paddingBottom: 94` on `askDock`); closed in the follow-up row below. | Continue V6 source comparison on Settings/Home remaining states. |
| 2026-07-12 | Done (code); e2e visual unverified | Claude | Wired the GENERATE screen's editable filename to persist (was a local-only mock). `GenerateOverlay.onGenerate` now returns the edited name; `startGeneration(file, name?)` best-effort calls `MemoraNative.renameAudioFile(file.id, name)` (in a `.catch(()=>{})`) and optimistically updates `latestFile.title` when the name changed and is non-empty. スキップ still generates with the original name. `runGeneration` (unchanged) keys off `file.id`, so the rename does not affect transcription/summary. Template/model still flow only through settings — passing the chosen template into `generateSummary` remains blocked on the summary-options contract expansion. | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Not e2e-screenshot-verified: reaching+editing the GENERATE filename (top input) then tapping 生成 (bottom edge) is a multi-tap live-recording sequence and both extremes are tap-unreliable (§F). The underlying `renameAudioFile` bridge was already proven end-to-end in earlier sessions, and this is a thin wiring on top. | Manually record→stop→edit name→生成 and confirm Home shows the renamed file. Expand the summary-options contract to carry the chosen template/model. |
| 2026-07-12 | Done (code); export-sheet visual unverified | Claude | Per an explicit user decision ("align to V6 appearance"), replaced File Detail's content-scope export sheet (a native `pageSheet` with すべて/要約/文字起こし chips + iOS share) with V6's destination-based export sheet (`docs/design/source/Memora Redesign v6.dc.html` lines 1178-1200): a floating bottom card (reusing the proven `sheetBackdrop`/`sheet`/`sheetHandle` pattern shared with the more sheet) titled 書き出す, with three rows — Notion に転記 (black icon, 未接続), ChatGPT に共有 (#10A37F icon, 未接続), and Markdown / TXT / SRT で書き出す (#8E8EA0 icon). Notion/ChatGPT show a 準備中 alert; the Markdown/TXT/SRT row calls the real `Share.share` (now always exports title+summary+transcript). Removed the now-unused `exportContent` state and its styles. | `npm run typecheck` passed; `npx expo export --platform web` succeeded. The sheet was NOT screenshot-verified: opening it needs a tap on the top-row share icon, and top-of-screen taps don't register reliably (the tap calibration is derived from lower-screen points; §F). It reuses the exact floating-card pattern already visually confirmed for the more sheet, so rendering is low-risk. | Manually open the export sheet to eyeball the three destination rows. The Notion/ChatGPT rows are intentionally 未接続 mocks per V6. |
| 2026-07-12 | Done (code); transcript/memo tab visual unverified | Claude | V6 fidelity pass on the File Detail transcript + memo tabs, comparing `FileDetailScreen.tsx` against the `docs/design/source/Memora Redesign v6.dc.html` lines 1127-1168. Fixes: transcript body `bodyText` 16→14px (V6 transcript is 14px/1.7; this style is shared with the summary 要約 body, also 14 in V6); segment speaker color `textSubtle`→`textMuted` (#3A3A3C per V6); segment time got `fontWeight: 500` (V6 mono 500); memo edit/display/placeholder line-height 21→25 (V6 1.8em). Memo/input corner radii kept at golden `radius.lg` per the standing radii decision (V6's 12-14 are non-golden). | `npm run typecheck` passed; `npx expo export --platform web` succeeded. The summary tab was re-verified rendering correctly on the simulator, but the transcript and memo tabs were NOT screenshot-verified: switching File Detail tabs by tap did not register reliably (screen-position tap drift, plan §F) even after an app relaunch. Changes are font-size/color/line-height only. | Manually switch to the 文字起こし and メモ tabs on a device to eyeball the 14px transcript text and memo line-height. |
| 2026-07-12 | Done (code); overlay visual unverified + GENERATE-screen gap found | Claude | V6 fidelity pass on the recording overlay, comparing `CaptureFlowProvider.tsx` against the `docs/design/source/Memora Redesign v6.dc.html` RECORDING block (lines 891-944). Minor fixes: the minimize/discard round-icon glyphs now use `textSubtle` (#6E6E80) per V6 (was ink) while the pause/play controls stay ink — added an optional `color` prop to `RoundIcon`; the live transcript-preview text line-height went 20→24 (V6 1.8em). Timer (44px mono), waveform (18 bars), status label, and stop/pause controls already matched V6. **Finding: the entire V6 GENERATE screen (lines 946-1003) was absent in RN — built in the follow-up row below.** | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Recording overlay verified live this session (see next row): the minimize/discard glyphs now render muted-gray per V6. | — |
| 2026-07-12 | Done (visually verified) | Claude | Built the missing V6 GENERATE (template/model select) screen in `CaptureFlowProvider.tsx` as a `GenerateOverlay`, inserting a new `'generate'` capture mode between recording-stop and the generating-progress overlay (V6 lines 946-1003). Recording-stop now routes to GENERATE instead of auto-starting generation; 生成 and スキップ both call the extracted `startGeneration(file)` (same `runGeneration` bridge sequence as before, unchanged), and 戻る cancels to idle with the file saved. The screen has an editable filename (local mock — persistence deferred), the 自動生成/カスタム生成 toggle, custom template chips (議事録/要点まとめ/アクション抽出/そのまま整形), and an AIモデル row that loads the real `summaryProvider` from settings (shows e.g. Gemini, better than V6's hardcoded ChatGPT-5). | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Live-verified on the `Memora RN Test` simulator via FAB→録音開始→stop: the GENERATE screen renders exactly like V6 (filename, dual icon+arrow, title/desc, bottom sheet), the 自動/カスタム toggle flips ink/faint correctly, custom template chips appear and select, and AIモデル shows the settings provider. The extreme-bottom 生成 button and top-left 戻る were not tap-confirmable (screen-edge coordinate drift, plan §F) but their handlers are trivial and typecheck-clean. | Optionally wire the GENERATE filename to `renameAudioFile` so the edited name persists; pass the chosen template/model into `generateSummary` once the summary options contract supports templates. |
| 2026-07-12 | Done (visually verified) | Claude | V6 fidelity pass on File Detail, comparing `FileDetailScreen.tsx` against the `docs/design/source/Memora Redesign v6.dc.html` FILE DETAIL block (lines 1018-1097). Fixes: header now renders via `Screen`'s `titleContent` as a 24px/700 single-line title + 12.5px muted date-meta (was the default 30px Screen title + 15px `textMuted` subtitle); tabs are now center-justified (V6 `justify-content:center`; was left-aligned) with 14px labels (was 13px); 決定事項 body switched to `textMuted` (#3A3A3C) with 24px line-height (V6 1.75em; was `textSubtle`/20). Summary section titles, chapter rows (mono time + chevron), and the 次のアクション タスク化 outline buttons already matched V6. | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Visually verified on the `Memora RN Test` simulator via `memora-rn://file/weekly-growth-0709`: 24px title, small muted meta, centered tabs, and the chapter/decision/action summary layout all render as in V6. | The placeholder loading/error/not-found File Detail states still use the default 30px `Screen` title (acceptable). Optional: replicate V6's 添付 photo grid header copy. |
| 2026-07-12 | Done (visually verified) | Claude | V6 fidelity pass on the Home file row, comparing `V6AudioFileRow.tsx` against the `docs/design/source/Memora Redesign v6.dc.html` HOME block (lines 396-455). Removed the per-row `borderBottom` hairline — V6's Home list separates file rows with 14px vertical padding whitespace only (sticky 今日/今週/以前 headers), no divider lines. Title (500/15), meta (12/quiet), and 2-line snippet (12.5/1.6/textMutedLight) already matched V6, so only the divider changed. | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Visually verified on the `Memora RN Test` simulator via `memora-rn://`: the hairline under the file row is gone, matching V6's whitespace-only row separation. (V6's inline processing spinner is still not replicated; RN keeps its determinate progress bar, which is acceptable and not a regression.) | If the user prefers visible dividers over V6's whitespace-only look, this is the row to revert. Optionally add the inline processing spinner to fully match V6. |
| 2026-07-12 | Done (visually verified) | Claude | V6 fidelity pass on Settings, comparing `SettingsScreen.tsx` against the `docs/design/source/Memora Redesign v6.dc.html` SETTINGS block (lines 773-889). Two structural gaps closed: (1) added the missing 言語 group (表示言語=日本語, 文字起こし言語=自動検出) between 連携 and 文字起こし・要約, matching V6's group order; (2) `SettingsGroupCard` now interleaves a `#F0F0F0` hairline divider between rows in multi-row cards (was flush/no separator), via `Children.toArray` + a `v6Divider` element. Card corner radius kept at the golden `radius.cardAlt` per the standing golden-ratio-radii decision (V6's 14 is a non-golden value). Mock/placeholder rows unchanged. | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Visually verified on the `Memora RN Test` simulator via `memora-rn://settings`: the 言語 group renders in order and inter-row dividers show in the アカウント/連携/言語 cards. | Optionally revisit the settings-card radius vs V6's 14 if the golden-ratio policy is relaxed. Continue V6 comparison on Home (main list) states if desired. |
| 2026-07-12 | Done (visually verified) | Claude | Closed the ~94px composer/keyboard gap: added a built-in `Keyboard` show/hide listener in `AskAIScreen.tsx` (iOS `keyboardWillShow/Hide`, others `keyboardDidShow/Hide`) that collapses `askDock`'s dock-reserved `paddingBottom` from 94 to `spacing.sm` while the keyboard is open (the floating dock is hidden behind the keyboard then anyway). JS-only, no native dep. | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Visually verified on the `Memora RN Test` simulator: with the keyboard open the focused composer now sits snug (~8px) above the keyboard instead of floating ~94px above it. | If any other bottom-anchored composer is added later, reuse this pattern (or extract a `useKeyboardVisible` hook). |
| 2026-07-12 | Done (visually verified) | Claude | V6 fidelity pass on the Tasks task row, comparing `TasksScreen.tsx` against the `docs/design/source/Memora Redesign v6.dc.html` TASKS block (lines 572-698). Fixed: circular 22×22 checkbox with 1.6 border (was 20×20/radius10/border1); each row now has a `#F5F5F5` (paleLine) bottom divider with 14px vertical padding (was no divider / 8px); meta row rebuilt to V6's `underlined source link · 3px dot · due badge` (was a soft chip with an arrow icon and no due). Overdue due badge is red, others muted. The add-sheet's floating-card/margins layout was intentionally kept (prior user override of V6's bottom-anchored sheet), so it was not touched. No data-model change. | `npm run typecheck` passed; `npx expo export --platform web` succeeded. Visually verified on the `Memora RN Test` simulator via deep link `memora-rn://tasks` + screenshot: circular checkboxes, per-row dividers, and `source · due` meta (期限切れ red, 今日/今後 muted) all render as in V6. | Continue the per-screen V6 source comparison (Ask/Settings remaining states); the Tasks add-sheet due/project chips (V6 lines 678-693) are still a mock stub vs V6's picker — build only when the task data model is decided. |
| 2026-07-12 | Done (code); visual unverified | Codex | File Detail 要約タブに V6 の「添付」グリッドを追加。添付の正本は既存メモ写真と決定し、`useMemoNotes` が取得済みの `photos` を読み取り専用で再利用した。3列サムネイル、端末内バッジ、Pro ストレージ案内、メモタブへ遷移する追加タイルを実装。既存の写真保存／削除ブリッジは変更なし。 | `npm run typecheck` passed; `npx expo export --platform web` succeeded (1.8MB bundle). 写真付き実データでの Simulator 目視は未確認。 | 写真を添付したファイルで要約タブのグリッドを Simulator 目視確認。テンプレート／モデルの `generateSummary` 契約拡張は別スコープ。 |
| 2026-07-12 | Done (code); GENERATE e2e visual unverified | Codex | GENERATE の選択テンプレート／設定済み AI プロバイダを既存 `generateSummary` 契約へ接続。監査の結果 `SummaryOptionsDTO.templateId` は TypeScript・Expo module・Swift DTO に既存だったため、契約拡張やネイティブ変更は不要だった。カスタム生成だけが安定 ID（`meeting-notes` 等）を渡し、自動生成／スキップはプロバイダのみを渡す。 | `npm run typecheck` passed; `npx expo export --platform web` succeeded (1.8MB bundle). 実録音からの GENERATE 完走は未目視。 | Simulator でカスタムテンプレート選択→生成を完走し、実サマライザ接続時に host adapter が `templateId` を解釈することを確認。 |
| 2026-07-12 | Done (code); iOS visual blocked | Codex | Expo SDK 57 互換の `react-native-gesture-handler@~2.32` と `@gorhom/bottom-sheet@^5.2.14` を追加。root を GestureHandler/BottomSheet provider で包み、File Detail の「その他」「書き出す」をパン操作・バックドロップ・下スワイプ閉じ対応のフローティングシートへ移行した。 | `npm run typecheck` passed; `npx expo export --platform web` succeeded (3.1MB bundle); `pod install` passed; simulator 向け `xcodebuild ... clean build` exited 0. 新 Dev Client は起動直後に SpringBoard へ戻り、最初の起動ログで `NativeLiquidGlassModule` 未登録を確認したため、iOS UI 目視は未実施。 | `NativeLiquidGlassModule` の native registration/Dev Client 起動問題を先に復旧してから、File Detail の2シートの提示・バックドロップ・パン閉じを Simulator で確認。 |
| 2026-07-12 | Done (native build); sheet interaction unverified | Codex | `NativeLiquidGlassModule` 未登録を診断。autolinking・codegen mapping は正しい一方、静的 `LiquidGlass` Pod の `LiquidGlassModule` オブジェクトが最終バイナリに dead-strip されていたため、Podfile の post-install に対象ライブラリだけの `-force_load` を追加した。 | このセッションで作成した再生成可能な `/tmp` DerivedData 約6GBを削除して空き容量を 2.8GB→9.0GB に回復。TTY の isolated iOS build が exit 0。Simulator に再インストールし、Home と File Detail 要約タブの起動をスクリーンショット確認。上端タップ自動化の不安定性により、新 Bottom Sheet の提示／パン閉じは未確認。 | File Detail の more/export sheet を手動または較正済みタップで開き、バックドロップ・下スワイプ閉じまで確認。 |
| 2026-07-12 | Done (environment recovery); sheet interaction unverified | Codex | 外部ボリュームの一時アンマウントで作業ディレクトリを失った Metro を LAN モードで再起動。さらに Simulator 内の `identityservicesd` が backing vnode の強制アンマウントにより `SIGBUS` を連鎖発生させていたため、対象 Simulator を停止・再起動して通知ループを解消した。 | `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB bundle）。`Memora RN Test` を再起動し Dev Client から Home および File Detail 要約タブを実画面で確認。File Detail の「その他」「ファイルを共有」アクセシビリティ要素は検出済みだが、Dev Client の常駐 Tools ボタンが上端の「その他」と重なり、リッチ Bottom Sheet の提示／バックドロップ／パン閉じは未確認。 | Dev Client Tools ボタンを非表示にしたうえで、File Detail の「その他」「書き出す」両シートの提示・閉じ操作を確認する。 |
| 2026-07-12 | 未確認（sheet interaction 検証は §F タップ不安定で未達） | Claude | 引き継ぎの完了主張（`FloatingBottomSheet` への移行、添付グリッド、gesture-handler/`BottomSheetModalProvider` 配線、Podfile `-force_load`）が実在することを read-only で確認。Simulator を再起動して最新 JS で File Detail をロードし、Dev Client の Tools ボタンが上端「その他」に重なる問題を実証（共有アイコン位置タップで Tools メニューが開いた）。dev メニュー内に「Tools button」非表示トグルを発見、Metro 接続（`192.168.86.26:8089`）も確認。**Tools ボタンをドラッグで画面下部へ退避してヘッダーの重なりは解消したが、その後も小さい共有/その他アイコン（および dev メニューのトグル）を `cliclick` で安定タップできず、2シートの提示／バックドロップ閉じ／下スワイプ閉じは未達。** コード変更なし。 | `npm run typecheck` passed。File Detail は最新 JS で正しく描画（ヘッダー・中央タブ・添付グリッド）を実スクショ確認。back ボタンや Tools ボタン等の大ターゲットのタップ／ドラッグは成功したが、右上の小アイコン（≈30–40px）は x=1350〜1412 / y=180〜210 の6点で全て不発（§F）。**シートの開閉挙動は未確認のまま。** | 実機 or インタラクティブ Simulator で人手により「…」「共有」をタップしてシート提示・バックドロップ・下スワイプ閉じを確認する（人手なら容易）。もしくは XCUITest / Maestro 等の堅牢な自動化に切替。dev メニューの「Tools button」を手動オフにすると重なりは恒久解消できる。 |
| 2026-07-13 | Done (presentation/backdrop/modal transitions); pan-down needs manual touch verification | Codex | `FloatingBottomSheet` が初期 `isOpen=false` でも `dismiss()` して modal status を `DISMISSING` にし得る競合を修正。実際に提示済みの場合だけ dismiss する ref を追加し、標準 gesture handle と明示 `index=0` を復元。File Detail のシート→リネーム／削除／Alert／Share は `onDismiss` 完了後に実行する pending action 方式へ変更。ヘッダー・シート行の button role と親 accessibility grouping も修正。ユーザー指示により File Detail／Home／Tasks のシートとダイアログは `regular` glass + 白 tint 0.78〜0.82、内部面 0.86 へ不透明化した（タブバーは変更なし）。 | 各変更後 `npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB）。XcodeBuildMCP で本番ヘッダーから「その他」「書き出す」を複数回提示し、両方の backdrop close、その他→削除確認、native file のその他→リネームをスクショ確認。File Detail export/delete と Tasks add の視認性改善を目視確認。Home シートは未目視。XcodeBuildMCP の drag は `FBSimulatorHIDEvent does not support touch move events` のため、下スワイプ閉じのみ未確認。 | 人手または実機タッチで標準 handle の下スワイプ閉じを1回確認。合格後、Home／Tasks を `FloatingBottomSheet` へ移行する別バッチと `SheetCard` 共通化を判断。 |
| 2026-07-13 | Done (Home filter / Tasks add); Home file-more and pan-down need manual verification | Codex | 白 tint 0.78・`regular` glass・黄金比 radius を集約する `SheetCard` を新設。File Detail の2シートを共通カードへ置換し、Home のフィルター／ファイル操作と Tasks の追加を `FloatingBottomSheet` へ移行した。Home の後続 rename/move/delete は `onDismiss` 後に実行する pending action 方式とし、Tasks は標準 `KeyboardAvoidingView` を維持。操作ボタンへ role を補完した。 | 変更後 `npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB、1560 modules）。Simulator で Home filter と Tasks add の表示・視認性・backdrop close をスクリーンショット／runtime UI で確認。Home file-more は行内 nested Pressable が UI tree で親に統合されるため未確認。pan-down は Simulator HID 制約のため未確認。 | 人手または実機で Home 行の「…」から操作シートと後続ダイアログを確認し、全共通シートの下スワイプ閉じを実タッチで確認する。 |
| 2026-07-13 | Done (Home file-more / delete transition); pan-down needs manual touch verification | Codex | `V6AudioFileRow` の nested Pressable を解消し、ファイル本体と44pxの「…」操作を兄弟要素へ分離。見た目・余白・ファイル遷移を維持しつつ、VoiceOver／runtime UI で個別操作として露出させた。 | `npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB、1560 modules）。Simulator でファイル本体と「…」が別buttonになること、操作シート表示、白カードの視認性、「削除」選択後にシートが閉じて確認ダイアログが表示されることをスクショ確認。削除確定は未実行。 | 人手／実機で pan-down close を確認。Home のタイトル変更／プロジェクト移動は同じ pending-action 経路だが、このセッションでは未実行。 |
| 2026-07-13 | Done (Home action coverage / accessibility roles) | Codex | Home のタイトル変更／プロジェクト移動について dismiss 後の Alert 遷移を確認。接続デバイス、検索、設定、プロジェクトカード、削除確認のキャンセル／削除へ明示的な button role を追加した。 | `npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB、1560 modules）。Simulator runtime UI でヘッダー3操作が独立 button として取得できること、タイトル変更とプロジェクト移動の各案内 Alert がシート閉鎖後に表示されることを確認。データ変更なし。 | 残る共通シート QA は実タッチの pan-down close。次は写真付きデータを用いた File Detail 添付グリッド確認、またはフォント永続化／EXConstants 修復を独立バッチで進める。 |
| 2026-07-13 | Done (attachment add-tile flow); photo thumbnail state still needs data | Codex | File Detail の質問バー、3タブ、チャプター行、タスク化へ操作 role／選択状態を補完。要約タブの添付セクションを実表示し、追加タイルからメモタブへ遷移する経路を確認した。 | `npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB、1560 modules）。Simulator で添付見出し、Ask AI caption、破線追加タイル、Pro 案内をスクロール後にスクショ確認。「メモで写真を添付」タップ後にメモタブ選択と写真添付面を確認。写真付きfixtureがないためサムネイル／端末内バッジは未確認。 | 写真付きデータが用意できた時点で3列サムネイルと端末内バッジだけ追加確認。次の独立実装はフォント永続化または EXConstants test-target 修復。 |
| 2026-07-13 | Done | Codex | SDK 57 互換 `@react-native-async-storage/async-storage` 2.2.0 を追加し、`/dev-fonts` の選択キーを保存・起動時復元。保存値を候補一覧で検証し、読込／保存失敗表示、選択チップの accessibility state も追加した。 | `npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB、1566 modules）。`pod install` succeeded（RNCAsyncStorage autolink/codegen）。XcodeBuildMCP の build/run succeeded、新 Dev Client を Simulator へ導入。Noto Sans JP 選択→アプリ完全終了→再起動→`/dev-fonts` 再表示後も選択状態が保持されることをスクショ確認。 | 次は `MemoraRNTests` の EXConstants build-for-testing 回帰を Xcode 診断し、テスト実行可能状態を復旧する。 |
| 2026-07-13 | Done | Codex | `MemoraRNTests` を診断。最初の失敗は EXConstants ではなく内蔵ディスク空き 116MiB による `write64 errno=28` だった。今回生成した `/tmp` QA DerivedData 1.8GiB と XcodeBuildMCP DerivedData 2.8GiB のみ削除し、QA の既定 DerivedData をリポジトリ配下 `.expo/ios-qa-derived-data`（物理的に HIKSEMI）へ変更。XcodeBuildMCP の永続 DerivedData も `.expo/xcodebuildmcp-derived-data` へ設定した。 | 内蔵空きは 116MiB→4.7GiB、HIKSEMI は 179GiB 空き。HIKSEMI 上で `npm run qa:ios:build` exit 0、`npm run qa:ios:test` exit 0。EXConstants 回帰は再現せず、テスト可能状態を確認。QA 成果物 2.9GiB は HIKSEMI 上。`npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB、1566 modules）。`npm audit` の moderate 10件は Expo 57→xcode 3.0.1→uuid 7.0.3 の既存依存鎖で、安全な修正候補はなく、提案される Expo 46 downgrade は不採用。 | 実タッチで共通 Bottom Sheet の pan-down close を確認。容量対策として Simulator runtime 等の Apple 管理領域は内蔵に残るため、今後も内蔵空きを監視する。 |
| 2026-07-13 | Done | Codex | Apple公式 `simctl runtime delete` で、30日以上未使用の iOS 26.0 beta（23A5260l、9.3GB）と iOS 26.2（23C54、7.8GB）を削除。使用中のiOS 26.5、直近使用のiOS 26.0正式版、HIKSEMI上のSimulator端末データは維持した。 | dry-runで対象2件を確認後に個別削除し、`runtime list` から消えたことを確認。関連dyld cacheも縮小し、内蔵空きは4.7GiB→29GiB、CoreSimulator cacheは15GB→6.9GB。`Memora RN Test` はiOS 26.5でBootedのまま。`npm run typecheck` passed、`npx expo export --platform web` succeeded。 | iOS 26.0正式版が不要と確定した場合は追加で7.5GB＋関連cacheを削除可能。現状は互換確認用として保持する。 |
| 2026-07-13 | Done | Codex | Tasks の追加シートを閉じる全経路で下書きを破棄し、キーボードの完了でも追加できるようにした。完了チェック、参照元、完了一覧のアクセシビリティ role/state も補完。 | `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。 | 実機または人手の Simulator 操作で共通 Bottom Sheet の pan-down close を確認。タスク永続化は正本のデータ契約決定後に別バッチで行う。 |
| 2026-07-13 | Done | Codex | UI/UX P0として、Home のデバイス状態を未接続に統一、削除確認へ削除中の無効化表示、読み込み失敗カードへ再試行を追加。 | `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。 | P1 の検索と Ask の分離、未接続機能の事前明示、プロジェクト詳細導線を別バッチで検討する。 |
| 2026-07-13 | Done | Codex | 「安っぽさ／AIテンプレ感」のポリッシュとして、Home の開発用録音名・内部英文をユーザー表示から除外、Ask を灰色カード型サジェストからフラットな記録検索UIへ変更、Tasks の追加操作をヘッダーへ移動して実利用に近い日本語fixtureへ更新、Settings の灰色カード連続を白地のフラットな設定リストへ整理した。 | `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。Simulator で Home／Ask／Tasks／Settings を再表示し、4画面の変更後スクリーンショットを確認。 | 実機で文字サイズ・余白・タブバーとの重なりを確認し、次は File Detail と録音／生成フローの装飾密度を同じ基準で監査する。 |
| 2026-07-13 | Done (File Detail visual); generation copy visual unverified | Codex | File Detail のSparklesと反復する枠付き「タスク化」を抑え、質問導線を「この記録について聞く」、添付説明を「質問時に参照されます」へ変更。録音後の生成画面は装飾アイコン列を外し、「自動生成／カスタム生成／AIモデル／生成」を「自動／テンプレート／要約モデル／処理を開始」へ整理した。処理契約は変更なし。 | `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。Simulator で File Detail の変更後表示を確認。録音後画面は実録音を開始していないため目視未確認。 | 実機の次回録音で、録音停止後の文字起こし・要約選択画面だけ確認する。 |
| 2026-07-13 | Done (code) | Codex | Reicon の公式 MCP CLI で検索したアイコンを使い、Expo UI の Ionicons 表示を Reicon React Native に統一した。`AppIcon` が既存の意味名を Reicon コンポーネントへ対応付けるため、画面の操作・アクセシビリティ名・STT/ネイティブ境界は変わらない。 | `npm run typecheck` passed。`npx expo export --platform web` succeeded（4,206 modules）。`git diff --check` passed。 | Simulator/実機で全画面のアイコン比率を目視確認し、必要なら個別の Reicon 候補を微調整する。 |

## Handoff Log

### 2026-07-13 Reicon icon migration

- Added `reicon-react-native@1.0.0` and a typed `AppIcon` adapter in `apps/mobile-expo/src/components/AppIcon.tsx`.
- The adapter maps all currently-used UI meanings (navigation, status, capture, file, Ask, Settings, and task controls) to Reicon components; existing screens retain their current props and interaction code.
- Added Reicon glyphs to the previously text-only file action sheets, export destinations, and task-add CTA so these controls scan consistently with the rest of the app.
- Reicon's official `reicon-mcp` CLI was used to inspect/apply the icon library choices. SwiftUI, STT core, and native bridge files were not modified.
- Verification: `npm run typecheck` passed; `npx expo export --platform web` succeeded; `git diff --check` passed.
- Follow-up: do one simulator/device visual pass for optical sizing, especially the tab dock and compact 10–15px indicators.
- Follow-up: fixed the Simulator render error caused by the missing `home` mapping in `AppIcon`. The Reicon peer dependency `react-native-svg` is now a direct app dependency and `RNSVG` is autolinked; install a newly built Dev Client before judging native SVG rendering.
- Follow-up: the Tasks dock badge is now a compact high-contrast count token, filter choices have Reicon file/folder/bookmark glyphs, and the Lifelog view pages horizontally across the current and previous 14 days. Swiping changes the displayed date and filters the timeline to that date.

### 2026-07-12 Keyboard avoidance for bottom-anchored inputs (JS-only)

- Wrapped the scroll body + `footerAccessory` composer in `Screen.tsx` with `KeyboardAvoidingView` (`behavior='padding'` on iOS, added `flex` style, `keyboardShouldPersistTaps='handled'`), and added the same wrapper to the `TasksScreen.tsx` add-task sheet and the `FileDetailScreen.tsx` rename dialog. Uses React Native's built-in component — no native dependency and no rebuild.
- The tab-screen footer composer keeps its existing `paddingBottom` for the floating dock; watch for a possible gap between composer and keyboard when the keyboard is open and trim it if it looks off on a real device.
- Verification: `npm run typecheck` passed; `npx expo export --platform web` succeeded with no bundling errors. The keyboard-lift itself was **not** visually confirmed on the Simulator — automated taps could not reliably focus the composer to raise the software keyboard (plan §F automation flakiness). This needs a manual/interactive pass.
- Protected STT core files and the `MemoraNative` bridge were not modified. `apps/mobile-expo` is untracked in git, so `git diff --check` shows nothing for these edits by design.
- Follow-up (same day): extended the same pattern to `AuthFlowScreen.tsx` (email/code stages) so the bottom-pinned submit buttons stay above the keyboard. Audited every `TextInput` in the app and confirmed full coverage: Ask composer + Memo editor via `Screen`'s KAV, Tasks add sheet + File Detail rename via their own KAV, AuthFlow now added. `npm run typecheck` and `npx expo export --platform web` passed. On-device keyboard lift still awaits a manual eyeball (Simulator tap-focus automation unreliable, §F).

### 2026-07-12 Isolated RN iOS QA and mutation validation

- Added `apps/mobile-expo/scripts/ios-qa.sh` plus `qa:ios:build` / `qa:ios:test` npm commands. QA uses a dedicated DerivedData path and arm64 simulator builds by default, so concurrent Xcode/Claude/Codex work does not share or lock the same build database.
- Reproduced the RN test bundle on the `Memora RN Test` iOS 26.5 simulator. The prior `EXConstants` module failure did not reproduce with isolated DerivedData.
- Fixed `MemoraSharedStoreBridgeAdapter.renameAudioFile` so an empty or whitespace-only title is rejected before repository lookup, keeping mutation validation independent of record existence.
- Verification: `zsh -n scripts/ios-qa.sh` and `npm run typecheck` passed; `qa:ios:build` produced `MemoraRNTests.xctest`; `qa:ios:test` passed 3/3 tests with 0 failures.
- UI screens/components and protected STT core files were not modified.

### 2026-07-12 Project move bridge foundation

- Added `moveAudioFile(id:projectId:)` to `MemoraAudioFileMutating` and exposed it through the Expo native module plus TypeScript facade.
- Native-file metadata persists a project reference and treats `null` or an empty value as Inbox.
- `MemoraSharedStoreBridgeAdapter` maps project UUIDs to `MemoraSharedAudioFileRecord.projectID`, maps Inbox back to `nil`, and rejects malformed project IDs before fetching or saving a record.
- Extended the existing Swift Testing suite to cover moving into a project, moving back to Inbox, and invalid project IDs.
- Verification: Expo typecheck passed; shared package 6/6 tests passed; isolated RN native build passed; RN bridge adapter 3/3 tests passed on the iOS 26.5 simulator.
- UI wiring remains intentionally separate so Claude can continue the visual lane without file conflicts.

### 2026-07-12 Processing retry queue foundation

- Added `MemoraProcessingRetryQueueing` and the default `MemoraFileProcessingRetryQueue` under the Expo native module.
- Added native/TypeScript/web facade methods to enqueue, list, record a failed attempt, and complete queued transcription/summary work.
- Queue entries persist as JSON in the RN app sandbox, deduplicate by audio file plus operation, and expose `retryQueueSource` in bridge diagnostics.
- Added Swift Testing coverage with an injected temporary storage URL for deduplication, error updates, attempt counting, persistence across queue instances, completion, and invalid operation rejection.
- Verification: Expo typecheck passed; CocoaPods registration passed; isolated RN native build passed; RN tests passed 4/4 on the iOS 26.5 simulator.
- No screen/component, protected STT, or protected AI file was changed.

### 2026-07-09

- Created this document to make the React Native / Expo migration resumable by other LLMs.
- Current recommendation: build Expo mock UI first, then add Dev Client + Swift native bridge.
- Backend remains unchanged.
- STT core remains protected.
- Next concrete task: scaffold `apps/mobile-expo` with Expo Router and mock screens, without touching Swift core.

### 2026-07-10 Shared adapter regression coverage

- Changed: added `MemoraTests/Adapters/MemoraSharedAudioFileStoreAdapterTests.swift` with a local repository mock.
- Coverage: all bridge-safe audio fields are mapped; saving an existing record updates it in place; saving a new record creates it; deleting by shared ID forwards the ID and removes the model.
- Verification: existing Memora iOS target build passed; RN iOS target build passed; shared package `swift test` passed with 4 tests; Expo `npm run typecheck` passed; `git diff --check` passed. `build-for-testing` reached the test target, and the new adapter test produced no remaining diagnostics, but the target stopped on the pre-existing missing `CreateProjectViewModel` referenced by `CreateProjectViewModelTests.swift`.
- Environment note: `xcodebuild ... test` with `generic/platform=iOS Simulator` cannot run unit tests because it requires a concrete simulator destination. `xcrun simctl list devices available` returned no device rows. Test-target compilation also has the unrelated missing `CreateProjectViewModel` issue; neither blocker was introduced by the adapter test.
- Decision: keep `MemoraSharedAudioFileStoreAdapter` in the existing app target and keep RN registries on native-file/sample sources. Package linkage alone must not change `persistenceScope` to `shared-swiftdata`.
- Next: restore a writable concrete simulator, run the adapter suite, then perform an explicitly approved App Group/store migration design before changing entitlements or `ModelContainer` ownership.

### 2026-07-09 Expo mock UI scaffold

- Changed: added Expo SDK 57 app in `apps/mobile-expo`, enabled Expo Router, created a small owned component system, mock data, native facade stub, and Home/File Detail/Ask AI/Settings/Preview screens.
- Files touched: `apps/mobile-expo/**`, this migration doc, and previously `README.md` for the migration-plan link.
- Verification: `npm run typecheck` passed. `npm run web -- --port 8088` is running at `http://localhost:8088`. Playwright with local Chrome rendered all initial routes and saved screenshots to `/tmp/memora-expo-screens`.
- Decisions: keep npm local to `apps/mobile-expo`; use owned RN components first; use Expo Go/web for mock UI and Dev Client later for native modules.
- Blockers: Playwright's bundled Chromium was not installed, so local Google Chrome was used for route verification. `npm audit` reports 10 moderate findings from the freshly generated Expo dependency tree; not addressed in this UI scaffold pass.
- Next: perform visual review on screenshots, tighten UI details, then add a typed native bridge shell for read-only audio file list/detail.

### 2026-07-09 Facade wiring

- Changed: Home and File Detail now load through `MemoraNative` facade hooks instead of importing mock arrays directly.
- Files touched: `src/native/MemoraNative.ts`, `src/features/files/useAudioFiles.ts`, `src/components/StateViews.tsx`, `src/screens/HomeScreen.tsx`, `src/screens/FileDetailScreen.tsx`.
- Verification: `npm run typecheck` passed. Playwright with local Chrome rendered `/`, `/file/weekly-growth-0709`, `/ask-ai`, `/settings`, and `/preview` after the facade change.
- Decisions: keep the facade async from the start so a real Swift/Expo native module can replace the mock without rewriting screen components.
- Blockers: none for mock UI. Real native bridge still requires Expo Dev Client / prebuild.
- Next: visual polish pass and then native module shell planning/implementation.

### 2026-07-09 Bridge contract and progress events

- Changed: added `MemoraNative.types.ts`, mock transcription event stream, `useTranscriptionTask`, `TranscriptionProgressCard`, and `BRIDGE_CONTRACT.md`.
- Files touched: `apps/mobile-expo/src/native/**`, `apps/mobile-expo/src/features/transcription/useTranscriptionTask.ts`, `apps/mobile-expo/src/components/TranscriptionProgressCard.tsx`, `apps/mobile-expo/src/screens/FileDetailScreen.tsx`, `apps/mobile-expo/app.json`, `apps/mobile-expo/package.json`, `apps/mobile-expo/README.md`.
- Verification: `npm run typecheck` passed. Playwright opened File Detail, switched to Transcript, tapped `開始`, and confirmed the mock event stream displayed `40%` progress and `チャンクを処理中です`. Additional state routes `/file/empty-transcript` and `/file/not-found` rendered.
- Decisions: installed and configured `expo-dev-client`, but did not run `expo prebuild` yet to avoid generating native folders before the bridge contract was explicit.
- Blockers: iOS simulator/native module verification still pending.
- Next: run prebuild, add the first Swift Expo Module shell named `MemoraNative`, and keep it read-only before touching any real Swift services.

### 2026-07-09 iOS Dev Client and local Expo Module shell

- Changed: generated `apps/mobile-expo/ios`, installed `expo-dev-client`, added local module `apps/mobile-expo/modules/memora-native`, and implemented the first Swift `MemoraNativeModule` shell.
- Files touched: `apps/mobile-expo/ios/**`, `apps/mobile-expo/modules/memora-native/**`, `apps/mobile-expo/package.json`, `apps/mobile-expo/package-lock.json`, `apps/mobile-expo/app.json`, `apps/mobile-expo/README.md`, `apps/mobile-expo/src/native/BRIDGE_CONTRACT.md`, and this migration doc.
- Verification: `npx expo-modules-autolinking resolve --platform ios --json` found `MemoraNative`; `cd apps/mobile-expo/ios && pod install` succeeded; `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`.
- Decisions: the native Swift module currently returns safe sample DTOs and emits a sample transcription event. It intentionally does not import or mutate existing Memora Swift services yet.
- Blockers: none for the native shell. Real data wiring still needs adapter files that stay outside protected STT core.
- Next: add read-only Swift adapter files for existing audio-file listing/detail data, then swap JS facade calls to prefer the real native module on iOS while keeping web mock fallback.

### 2026-07-09 RN facade native preference

- Changed: `apps/mobile-expo/src/native/MemoraNative.ts` now tries the local native Expo Module on non-web platforms and falls back to mock data when unavailable. Web is explicitly kept on the mock path so preview/progress demos stay useful without a native binary.
- Changed: `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift` now emits staged sample progress events after `startTranscription`, with cancellation support for the sample task.
- Files touched: `apps/mobile-expo/src/native/MemoraNative.ts`, `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift`, and this migration doc.
- Verification: `npm run typecheck` passed. Playwright verified the web Transcript progress card still reaches `40%` and shows `チャンクを処理中です`. Incremental iOS simulator build completed with `BUILD SUCCEEDED`.
- Decisions: native preference is limited to non-web to avoid the empty web module shadowing richer mock UI review states.
- Next: run the Dev Client on a simulator and visually confirm the Home list shows `Native bridge sample`; then introduce read-only adapter files for real audio file metadata.

### 2026-07-09 Read-only native adapter boundary

- Changed: added `MemoraAudioFileDTO` and `MemoraAudioFileReading` inside `apps/mobile-expo/modules/memora-native/ios`, and routed native audio-file list/detail calls through that reader boundary.
- Changed: added `getBridgeInfo()` to the native module, JS module wrappers, RN facade, and Settings screen so agents can quickly see whether the UI is using mock/sample/real data.
- Files touched: `apps/mobile-expo/modules/memora-native/ios/**`, `apps/mobile-expo/modules/memora-native/src/**`, `apps/mobile-expo/src/native/**`, `apps/mobile-expo/src/screens/SettingsScreen.tsx`, `apps/mobile-expo/README.md`, `apps/mobile-expo/src/native/BRIDGE_CONTRACT.md`, and this migration doc.
- Verification: `npm run typecheck` passed. `cd apps/mobile-expo/ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`.
- Decisions: the current reader is intentionally `MemoraSampleAudioFileReader` with `isRealDataConnected: false`; the next agent can replace that reader with a real read-only adapter without touching RN screens or STT core files.
- Historical blocker: simulator device creation once failed because of externalized CoreSimulator storage permissions. This was resolved in later migration work; see the current session log for validation status.
- Next: fix the local CoreSimulator storage location/permissions, run the Dev Client UI and inspect Settings Bridge diagnostics on simulator, then connect a real SwiftData/repository reader from outside the protected STT core.

### 2026-07-09 Public reader registry

- Changed: made `MemoraAudioFileDTO`, `MemoraAudioFileReading`, and `MemoraSampleAudioFileReader` public, and added `MemoraNativeAudioFileReaderRegistry.audioFileReader`.
- Changed: `MemoraNativeModule` now reads the current reader from the registry, which means the generated host app target can inject a real `SwiftDataAudioFileReader` later while the module keeps safe sample data by default.
- Files touched: `apps/mobile-expo/modules/memora-native/ios/MemoraAudioFileDTO.swift`, `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift`, `apps/mobile-expo/src/native/BRIDGE_CONTRACT.md`, and this migration doc.
- Verification: `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`.
- Decisions: do not make the Expo module import existing app-target SwiftData models directly. Use host-app injection once the RN target has a stable startup point and `ModelContainer`.
- Next: create the host-app `SwiftDataAudioFileReader` and set `MemoraNativeAudioFileReaderRegistry.audioFileReader` during app startup after simulator/storage issues are resolved.

### 2026-07-09 Settings bridge facade

- Changed: added `SettingsDTO`, `loadSettings`, and `saveSettings` to the local `MemoraNative` module TS wrappers and Swift module.
- Changed: `apps/mobile-expo/src/native/MemoraNative.ts` now tries native settings calls on non-web and falls back to in-memory mock settings.
- Changed: Settings screen now builds its sections from `MemoraNative.loadSettings()` and `MemoraNative.getBridgeInfo()` instead of importing `settingsGroups` directly.
- Files touched: `apps/mobile-expo/modules/memora-native/src/**`, `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift`, `apps/mobile-expo/src/native/MemoraNative.ts`, `apps/mobile-expo/src/screens/SettingsScreen.tsx`, and this migration doc.
- Verification: `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`. Playwright verified `/settings` still shows settings rows, Bridge diagnostics, and `Gemini`.
- Decisions: settings are intentionally in-memory for now. Do not move secrets into RN; API keys and sensitive state should stay in Swift/keychain-backed services when the real adapter is added.
- Next: identify the existing Swift settings/keychain source of truth and replace the in-memory native settings dictionary with a safe adapter.

### 2026-07-09 Typed settings registry

- Changed: added `MemoraSettingsDTO.swift` with `MemoraSettingsDTO`, `MemoraSettingsReadingWriting`, `MemoraNativeSettingsRegistry`, and `MemoraSampleSettingsStore`.
- Changed: `MemoraNativeModule.loadSettings()` and `saveSettings()` now call `MemoraNativeSettingsRegistry.settingsStore`.
- Changed: `getBridgeInfo()` now reports `settingsSource`, and Settings Bridge shows it alongside `audioFileSource`.
- Files touched: `apps/mobile-expo/modules/memora-native/ios/MemoraSettingsDTO.swift`, `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift`, module TS wrappers, RN facade, Settings screen, bridge contract docs, and this migration doc.
- Verification: `npm run typecheck` passed. `cd apps/mobile-expo/ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`. Playwright verified `/settings` shows settings rows, Bridge diagnostics, `Settings source`, and `Gemini`.
- Decisions: the default store is memory-only sample state. A later host-app adapter should read/write through the real Swift settings/keychain surfaces.
- Next: inject a real settings store from the host app target. Keep raw API keys, provider secrets, and Keychain values out of React Native state.

### 2026-07-09 Persistent non-secret settings

- Changed: added `MemoraUserDefaultsSettingsStore` and made it the default `MemoraNativeSettingsRegistry.settingsStore`.
- Changed: web/native-unavailable fallback in `apps/mobile-expo/src/native/MemoraNative.ts` now persists the same non-secret `SettingsDTO` to `localStorage`.
- Changed: `BridgeInfoDTO.settingsSource` now includes `userdefaults`, and Settings Bridge treats `userdefaults` as a healthy non-secret native store.
- Files touched: `apps/mobile-expo/modules/memora-native/ios/MemoraSettingsDTO.swift`, `apps/mobile-expo/src/native/**`, `apps/mobile-expo/src/screens/SettingsScreen.tsx`, `apps/mobile-expo/README.md`, bridge contract docs, and this migration doc.
- Verification: `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`. Playwright verified `/settings` and confirmed web `localStorage` fallback reloads `API first` / `Local`.
- Decisions: this still does not store API keys or secrets in React Native. `UserDefaults` is only for non-secret UI state.
- Next: run typecheck/native build/web smoke, then add a host-app adapter only after identifying the existing Swift settings/keychain source of truth.

### 2026-07-09 Interactive Settings controls

- Changed: Settings screen now has controls for transcription mode, summary provider, and SpeechAnalyzer.
- Changed: each control calls `MemoraNative.saveSettings`, so it exercises the same facade that native iOS uses.
- Files touched: `apps/mobile-expo/src/screens/SettingsScreen.tsx` and this migration doc.
- Verification: `npm run typecheck` passed. Playwright clicked `API` and `Local`, reloaded `/settings`, and confirmed `API first`, `Local`, and `Settings source` still render.
- Decisions: this is still non-secret settings only; no API key or provider credential enters RN state.
- Next: connect these controls to a host-app Swift settings/keychain adapter after the source of truth is chosen.

### 2026-07-09 Recording/import bridge shell

- Changed: added `startRecording`, `stopRecording`, and `importAudio` to the local Expo module TypeScript wrappers and Swift module.
- Changed: RN facade now prefers native recording/import methods on non-web and falls back to generated mock DTOs when native is unavailable.
- Files touched: `apps/mobile-expo/modules/memora-native/src/**`, `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift`, `apps/mobile-expo/src/native/MemoraNative.ts`, and this migration doc.
- Verification: `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`.
- Decisions: this is a bridge shell only. It returns placeholder DTOs and intentionally does not start AVFoundation, write files, or modify existing recording/STT core services.
- Next: identify the existing Swift recording/import service boundary, then replace placeholders with adapter calls outside protected STT core files.

### 2026-07-09 Recording/import registry boundary

- Changed: added `MemoraRecordingSessionDTO`, `MemoraRecordingImportHandling`, `MemoraNativeRecordingImportRegistry`, and `MemoraSampleRecordingImportHandler` under the local Expo module.
- Changed: `MemoraNativeModule.startRecording`, `stopRecording`, and `importAudio` now call the current registry handler instead of constructing inline placeholders.
- Changed: `getBridgeInfo()` now reports `recordingSource`, and the RN Settings Bridge diagnostics display it alongside module, audio-file, and settings sources.
- Existing boundaries inspected: `AudioRecorder`, `AudioFileImportService`, `CaptureSourceRegistry`, and `RecordingViewModel`.
- Files touched: `apps/mobile-expo/modules/memora-native/ios/MemoraRecordingBridgeDTO.swift`, `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift`, module/RN native TypeScript types, `apps/mobile-expo/src/native/MemoraNative.ts`, `apps/mobile-expo/src/screens/SettingsScreen.tsx`, `apps/mobile-expo/README.md`, bridge contract docs, and this migration doc.
- Verification: `npm run typecheck` passed. `cd apps/mobile-expo/ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`. Playwright verified `/settings` shows `Recording source`, `Settings source`, and Bridge.
- Decisions: do not import app-target SwiftData/AVFoundation services directly into the Expo module. The next real-data pass should add a host-app adapter that owns `AudioRecorder`, `AudioFileImportService`, `ModelContext` or repository access, then assigns `MemoraNativeRecordingImportRegistry.handler` during RN app startup.
- Historical blocker: the simulator storage issue described here was resolved later; see the current session log for validation status.
- Next: implement the host-app recording/import adapter outside protected STT core files, then replace the current preview Home controls with real file/recording outputs.

### 2026-07-09 Home recording/import bridge controls

- Changed: wired Home action buttons to `MemoraNative.startRecording`, `stopRecording`, and `importAudio`.
- Changed: Home now displays a bridge status panel showing the active recording session or returned `AudioFileDTO` title/status.
- Changed: added `accessibilityRole` and `accessibilityLabel` to the action buttons so browser and device tests can target them reliably.
- Files touched: `apps/mobile-expo/src/screens/HomeScreen.tsx`, `apps/mobile-expo/README.md`, and this migration doc.
- Verification: `npm run typecheck` passed. Playwright opened `/`, clicked `録音を開始`, confirmed `録音セッションを開始しました`, clicked `録音を停止`, confirmed `ブリッジからファイルDTOを受け取りました`, clicked `音声を取り込み`, and confirmed `import-preview.m4a`.
- Decisions: import uses a fixed preview URI for now because real document picker/native import selection should wait until the host-app recording/import adapter is in place.
- Next: replace preview import behavior with a native picker or document-picker flow, then append returned real files into the list once the source of truth is connected.

### 2026-07-09 Native file metadata rename/delete

- Changed: added `renameAudioFile(id,title)` and `deleteAudioFile(id)` to the local Expo module, TS module wrappers, web stubs, and RN facade.
- Changed: `MemoraNativeAudioFileMetadataStore` can now rename native-file metadata and delete native-file metadata plus the stored file when present.
- Changed: `useAudioFiles` exposes `removeAudioFile`, and Home shows a trash action only for safe bridge-generated/native-file IDs (`native-recording-`, `native-import-`, `import-`).
- Files touched: `apps/mobile-expo/modules/memora-native/ios/**`, `apps/mobile-expo/modules/memora-native/src/**`, `apps/mobile-expo/src/native/**`, `apps/mobile-expo/src/features/files/useAudioFiles.ts`, `apps/mobile-expo/src/components/AudioFileCard.tsx`, `apps/mobile-expo/src/screens/HomeScreen.tsx`, bridge docs, README, and this migration doc.
- Verification: `npm run typecheck` passed. Playwright opened Home on web, generated a fallback recording, verified the trash button appeared, clicked delete, and confirmed the visible file count decreased. `cd apps/mobile-expo/ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`.
- Decisions: sample/mock records are intentionally not deletable from Home. Rename API exists but no RN edit-title UI is connected yet.
- Next: add rename UI in File Detail or Home, then replace the local JSON metadata mutation path with a host-app SwiftData/repository adapter.

### 2026-07-09 File Detail rename UI

- Changed: File Detail now exposes inline title editing for safe bridge-generated/native-file records and calls `MemoraNative.renameAudioFile`.
- Changed: `useAudioFile` exposes `setAudioFile` so a successful rename updates the detail screen immediately.
- Changed: `AudioFileCard` no longer nests a delete `Pressable` inside the card-open `Pressable`; open/delete are separate sibling targets for cleaner web and native behavior.
- Files touched: `apps/mobile-expo/src/screens/FileDetailScreen.tsx`, `apps/mobile-expo/src/features/files/useAudioFiles.ts`, `apps/mobile-expo/src/components/AudioFileCard.tsx`, this migration doc, README, and bridge contract docs.
- Verification: `npm run typecheck` passed. Playwright with local Google Chrome generated a fallback recording, opened it through the card open action, edited the title to `RN renamed bridge file`, saved, returned to Home, and confirmed the renamed title was visible. It also confirmed no nested button warning text was visible.
- Decisions: edit-title UI remains hidden for mock/sample records. Web fallback rename is in-memory only and is reset by a full browser reload; native-file rename persists through the local JSON metadata store.
- Next: replace local JSON metadata rename/delete with a host-app SwiftData/repository adapter and run the flow in iOS Dev Client after the local CoreSimulator storage issue is fixed.

### 2026-07-09 Audio file mutation registry

- Changed: added public `MemoraAudioFileMutating` and `MemoraNativeAudioFileMutationRegistry` to the local Expo module.
- Changed: renamed the default native-file implementation to `MemoraNativeFileAudioFileStore`, conforming to both `MemoraAudioFileReading` and `MemoraAudioFileMutating`. `MemoraNativeFileAudioFileReader` remains as a typealias for compatibility with earlier docs/code references.
- Changed: `MemoraNativeModule.renameAudioFile` and `deleteAudioFile` now call `audioFileMutator`; `MemoraNativeFileRecordingImportHandler` now persists generated DTOs through the mutation registry instead of calling the JSON metadata store directly.
- Changed: `getBridgeInfo()` now returns `audioFileMutationSource`, and RN Settings shows it as `Mutation source`.
- Files touched: `apps/mobile-expo/modules/memora-native/ios/MemoraAudioFileDTO.swift`, `MemoraNativeModule.swift`, `MemoraRecordingBridgeDTO.swift`, module/RN TS bridge types, `MemoraNative.ts`, `SettingsScreen.tsx`, README, bridge contract docs, and this migration doc.
- Verification: `npm run typecheck` passed. `cd apps/mobile-expo/ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` completed with `BUILD SUCCEEDED`. Playwright with local Google Chrome verified `/settings` shows `Mutation source` on web.
- Decisions: existing `AudioFileRepository` is internal to the Swift app target, so the Expo module should not import it directly. The next real-data pass should add a host-app adapter that conforms to `MemoraAudioFileReading` and `MemoraAudioFileMutating`, then assign both registries during app startup.
- Next: create the host-app SwiftData/repository adapter and injection point after deciding how the RN target will own or share a `ModelContainer`.

### 2026-07-09 RN iOS bridge bootstrap

- Changed: added `configureMemoraNativeBridge()` to `apps/mobile-expo/ios/MemoraRN/AppDelegate.swift` and call it before React Native starts.
- Changed: bootstrap currently assigns `MemoraNativeFileAudioFileStore` to both audio-file reader and mutator registries, `MemoraNativeFileRecordingImportHandler` to recording/import, and `MemoraUserDefaultsSettingsStore` to settings.
- Files touched: `apps/mobile-expo/ios/MemoraRN/AppDelegate.swift` and this migration doc.
- Verification: `npm run typecheck` passed. First native build failed because `MemoraNative` must be imported with the same access level as Expo's generated provider; after changing to `internal import MemoraNative`, `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`.
- Decisions: keep adapter injection in the generated RN host app boundary. Do not make the Expo module import existing app-target SwiftData models or repository types directly.
- Next: replace the current bootstrap defaults with SwiftData/repository adapters after a stable `ModelContainer` ownership path is chosen for the RN target.

### 2026-07-09 Bootstrap file split and real-data diagnostics

- Changed: moved RN host-app registry setup out of `AppDelegate.swift` into `ios/MemoraRN/MemoraNativeBridgeBootstrap.swift`.
- Changed: added the new Swift file to `ios/MemoraRN.xcodeproj/project.pbxproj` Sources so it is compiled into the RN host app.
- Changed: `AppDelegate` now only calls `MemoraNativeBridgeBootstrap.configureDefaults()` before React Native starts.
- Changed: added generic `MemoraNativeBridgeBootstrap.configure(audioFileReader:audioFileMutator:recordingImportHandler:settingsStore:)` so the next SwiftData pass can swap all four registries without editing `AppDelegate`.
- Changed: `MemoraNativeModule.getBridgeInfo()` now derives `isRealDataConnected` from registry sources, currently true when either audio-file reader or mutator reports `swiftdata`.
- Files touched: `apps/mobile-expo/ios/MemoraRN/AppDelegate.swift`, `apps/mobile-expo/ios/MemoraRN/MemoraNativeBridgeBootstrap.swift`, `apps/mobile-expo/ios/MemoraRN.xcodeproj/project.pbxproj`, `apps/mobile-expo/modules/memora-native/ios/MemoraNativeModule.swift`, bridge docs, and this migration doc.
- Verification: `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Playwright with local Google Chrome verified `/settings` still shows Bridge and `Mutation source` on web.
- Decisions: the bootstrap file is the intended home for future host-app adapter wiring. Keep `internal import MemoraNative` in RN host Swift files to match Expo-generated module-provider imports.
- Next: add a SwiftData-backed bootstrap path once `ModelContainer` ownership for the RN target is explicit, then pass those adapters through `MemoraNativeBridgeBootstrap.configure(...)`.

### 2026-07-09 Existing SwiftData boundary inspection

- Inspected: `Memora/Core/Models/AudioFile.swift`, `Memora/Core/Repositories/AudioFileRepository.swift`, `Memora/App/MemoraApp.swift`, `Memora/App/ContentView.swift`, and `apps/mobile-expo/ios/MemoraRN.xcodeproj/project.pbxproj`.
- Finding: `AudioFileRepositoryProtocol` already has the read/mutate methods the RN bridge needs: `fetchPage`, `fetch(id:)`, `save`, and `delete`.
- Finding: `AudioFile` is an internal app-target SwiftData `@Model`; `AudioFileRepository` is also internal and depends on `ModelContext`.
- Finding: the generated `MemoraRN` target currently compiles `AppDelegate.swift`, `MemoraNativeBridgeBootstrap.swift`, and Expo/CocoaPods support files only. It does not compile existing `Memora/Core` app models or repositories.
- Verification: `npm run typecheck` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`.
- Decision: do not make the local Expo module import `AudioFile`, `AudioFileRepository`, or other app-target internals directly. The safe next step is a target-sharing decision: either add a narrow set of existing model/repository files to the RN host target, extract a shared Swift package/framework, or provide a native app service layer that owns `ModelContainer` and emits `MemoraAudioFileDTO`.
- Next: pick the target-sharing approach, then implement a host-app adapter that calls `MemoraNativeBridgeBootstrap.configure(...)` with `sourceDescription = "swiftdata"` for reader/mutator so Settings can report `isRealDataConnected: true`.

### 2026-07-09 Ask AI scoped interaction

- Changed: `apps/mobile-expo/src/screens/AskAIScreen.tsx` now has interactive file/project/global scope controls.
- Changed: each scope keeps its own message history. The global scope starts empty, project scope starts with a project-level prompt, and file scope keeps the original mock conversation.
- Changed: added text input, disabled send state, loading state, generated assistant answer, and source pills. This keeps the review loop deterministic until a real retrieval/query facade is chosen.
- Files touched: `apps/mobile-expo/src/screens/AskAIScreen.tsx` and this migration doc.
- Verification: `npm run typecheck` passed. Headless local Google Chrome controlled through CDP verified `/ask-ai` global empty state, question input, send, generated answer text, `Settings bridge diagnostics` source pill, and project-scope history.
- Decisions: Ask AI remains frontend-only for now. Do not connect to `KnowledgeQueryService`, AI providers, or backend routes until the retrieval/query bridge boundary is defined.
- Next: add `MemoraNative.queryKnowledge` or an HTTP/native facade once the source-of-truth boundary for search/retrieval is decided.

### 2026-07-09 Ask AI query bridge facade

- Changed: added `KnowledgeQueryRequestDTO`, `KnowledgeQueryResponseDTO`, and `KnowledgeQueryScope` to the RN native bridge types.
- Changed: `AskAIScreen` now calls `MemoraNative.queryKnowledge` instead of building responses directly inside the screen.
- Changed: added `MemoraKnowledgeQueryDTO.swift` with `MemoraKnowledgeQuerying`, `MemoraNativeKnowledgeQueryRegistry`, and `MemoraSampleKnowledgeQuery`.
- Changed: `MemoraNativeModule.queryKnowledge` now routes through the registry, and `MemoraNativeBridgeBootstrap.configure(...)` can inject a future host-app query adapter.
- Changed: `getBridgeInfo()` now reports `knowledgeQuerySource`; Settings Bridge shows `Knowledge source`.
- Files touched: `apps/mobile-expo/src/native/**`, `apps/mobile-expo/modules/memora-native/**`, `apps/mobile-expo/ios/MemoraRN/MemoraNativeBridgeBootstrap.swift`, `apps/mobile-expo/src/screens/AskAIScreen.tsx`, `SettingsScreen.tsx`, README, bridge contract docs, and this migration doc.
- Verification: `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. Headless local Google Chrome via CDP verified `/ask-ai` global query response and `/settings` Knowledge source.
- Decisions: keep the sample query deterministic. Do not call `KnowledgeQueryService`, provider networking, or `bot-server` from the local Expo module until the retrieval/query source-of-truth boundary is chosen.
- Next: add a host-app query adapter that owns the real retrieval dependencies, then inject it through `MemoraNativeBridgeBootstrap.configure(...)`.

### 2026-07-10 Summary bridge facade

- Changed: added `SummaryRequestDTO` and `SummaryDTO` support to the RN and local Expo module contracts.
- Changed: added `MemoraSummaryGenerating`, `MemoraNativeSummaryRegistry`, and `MemoraSampleSummaryGenerator` in `MemoraSummaryDTO.swift`.
- Changed: `MemoraNativeModule.generateSummary` routes through the summary registry, and `MemoraNativeBridgeBootstrap.configure(...)` accepts a summary generator for future host-app injection.
- Changed: `getBridgeInfo()` now reports `summarySource`; Settings Bridge displays it alongside the other data boundaries.
- Changed: `MemoraNative.generateSummary` prefers the native module and retains deterministic web/mock fallback behavior.
- Files touched: `apps/mobile-expo/src/native/**`, `apps/mobile-expo/modules/memora-native/**`, `apps/mobile-expo/ios/MemoraRN/MemoraNativeBridgeBootstrap.swift`, `apps/mobile-expo/src/screens/SettingsScreen.tsx`, README, bridge contract docs, and this migration doc.
- Verification: `npm run typecheck` passed. `cd ios && pod install` passed. `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`.
- Decisions: keep summary generation as a replaceable native boundary. Do not call `AIService`, provider SDKs, Keychain, or backend routes from the local Expo module.
- Historical blocker: the simulator storage issue described here was resolved later; see the current session log for validation status.
- Next: decide the SwiftData/shared-target strategy, then inject real reader/mutator/query/summary adapters from the host app in a separate native-data PR.

### 2026-07-10 File Detail summary action

- Changed: the hero `要約` action and Summary tab `要約を再生成` action now call `MemoraNative.generateSummary`.
- Changed: added generating, disabled, error, and result-reflection states. A successful response updates the visible summary and marks the local DTO as `summarized`.
- Files touched: `apps/mobile-expo/src/screens/FileDetailScreen.tsx` and this migration doc.
- Verification: `npm run typecheck` passed. `curl -fsS http://localhost:8088/file/weekly-growth-0709` returned the Expo web document. Full browser click verification was unavailable because the Chrome CDP endpoint was not exposed in the current shell.
- Decisions: keep provider selection at the bridge call boundary for now; the screen uses the current settings-compatible `Gemini` default until settings context is injected.
- Blockers: live iOS Simulator remains blocked by the existing CoreSimulator storage/permission issue. Browser CDP was also unavailable for this turn.
- Next: verify the button interaction in the Expo web/Dev Client, then choose the host-app SwiftData/shared-target strategy before implementing a real summary adapter.

### 2026-07-10 SwiftData target-sharing decision record

- Added: `docs/react-native-swiftdata-target-sharing-decision.md`.
- Finding: direct target membership would pull in `AudioFile`'s relationship graph and create schema/store drift risk.
- Decision: recommend a shared Swift package/framework for SwiftData schema, repository, DTO mapping, and host-side adapters. Keep the Expo module independent from `Memora/Core` internals.
- Fallback: backend/API-only RN data is acceptable only if local SwiftData parity is explicitly deferred.
- Next: inspect XcodeGen/package configuration and create a minimal shared package skeleton in a separate native-data batch. Do not move the full model graph or touch STT core in the same batch.

### 2026-07-10 Summary provider settings integration

- Changed: File Detail now loads `MemoraNative.loadSettings()` and passes the selected `summaryProvider` into `MemoraNative.generateSummary`.
- Changed: successful summary responses display provider and generated timestamp metadata.
- Files touched: `apps/mobile-expo/src/screens/FileDetailScreen.tsx` and this migration doc.
- Verification: `npm run typecheck` passed. HTTP 200 responses confirmed for `/file/weekly-growth-0709` and `/ask-ai`. `git diff --check` passed.
- Decisions: keep provider selection in RN settings DTOs while keeping provider secrets and actual provider calls on the native side.
- Next: browser click verification, then shared package skeleton work.

### 2026-07-10 Shared package skeleton

- Changed: added `Packages/MemoraSharedData` with `MemoraSharedAudioFileRecord` and `MemoraSharedAudioFileStore` contracts.
- Changed: added a Swift Testing round-trip test for the JSON-friendly shared record.
- Changed: added `MemoraInMemoryAudioFileStore` with page ordering, update, and delete coverage as a safe adapter test double.
- Changed: registered `MemoraSharedData` as a local package dependency in `project.yml` so the existing `Memora` target builds the package.
- Changed: linked the same local package into the RN Xcode host target and added a compile-time contract probe in `MemoraNativeBridgeBootstrap.swift`.
- Deliberately not changed: existing `@Model` classes, `ModelContainer`, migrations, STT, provider services, and Expo module internals.
- Next: make the original SwiftUI target consume the package contract, then implement a repository adapter behind tests.

### 2026-07-10 Shared store contract test double

- Changed: added `MemoraInMemoryAudioFileStore` for deterministic adapter tests.
- Changed: added Swift Testing coverage for page ordering, update, delete, and JSON round-trip behavior.
- Verification: `swift test` passed with 2 tests. Expo `npm run typecheck` passed. `xcodebuild -project Memora.xcodeproj -scheme Memora -destination 'generic/platform=iOS Simulator' build` passed with `BUILD SUCCEEDED`. `git diff --check` passed.
- Decisions: keep the test double in the shared package, but do not use it for production bridge data or mark it as SwiftData.
- Next: build a repository mapper around the actual shared schema after ModelContainer ownership is settled.

### 2026-07-10 Existing repository mapper

- Changed: added `Memora/Core/Adapters/MemoraSharedAudioFileStoreAdapter.swift`.
- Changed: mapped list/page/read/save/delete operations and summary/transcription fields into the shared DTO.
- Deliberately not changed: `AudioFile`, `AudioFileRepository`, SwiftData schema, migrations, STT, and Expo module internals.
- Next: add adapter-focused tests and determine how the separate RN host target receives the same `ModelContainer`/repository context.

### 2026-07-10 RN shared package linking

- Changed: added `XCLocalSwiftPackageReference` and `XCSwiftPackageProductDependency` entries for `MemoraSharedData` to `apps/mobile-expo/ios/MemoraRN.xcodeproj/project.pbxproj`.
- Changed: imported `MemoraSharedData` from `MemoraNativeBridgeBootstrap.swift` and added a contract probe that creates the in-memory store without changing production registry defaults.
- Fixed: aligned the package minimum platform declaration with SwiftPM syntax and the RN target deployment compatibility.
- Verification: final RN iOS Simulator build passed with `BUILD SUCCEEDED`; existing Memora iOS Simulator build passed with `BUILD SUCCEEDED`; `swift test` passed with 2 tests; Expo `npm run typecheck` passed.
- Decision: package linking is complete, but real SwiftData remains disabled until the RN target receives the actual model/repository context.
- Next: choose target-sharing of the model graph or a host service boundary, then implement the first real RN reader adapter.

### 2026-07-10 Shared store location contract

- Changed: added `MemoraSharedStoreLocation.storeURL(in:)` and future App Group resolution to `MemoraSharedData`.
- Changed: added a stable URL contract test.
- Deliberately not changed: entitlements, current `Application Support` store location, SwiftData schema, and target source of truth.
- Next: choose a new App Group identifier and perform a separate persistent-store migration design before enabling shared storage.

### 2026-07-10 Store backup utility

- Changed: added `MemoraStoreMigration.copyStore(from:to:)` with source validation, destination overwrite protection, directory creation, and SQLite sidecar copying.
- Changed: added a temporary-directory test covering the main store, `-shm`, and `-wal` files.
- Safety: this utility is not wired into app startup and must only run while the SwiftData store is closed.
- Next: define backup/rollback and App Group ownership before adding a production migration hook.

### 2026-07-10 Store migration preflight hardening

- Changed: `MemoraStoreMigration.copyStore(from:to:)` now rejects any existing destination sidecar before copying the main store.
- Changed: added tests for an existing destination `-wal` file and a missing source store; the existing main/sidecar copy test remains covered.
- Verification: `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Decision: keep this utility as a closed-store, explicit migration primitive. It is not called during RN or SwiftUI app startup and does not enable App Group entitlements.
- Next: resolve the existing `MemoraTests` missing `CreateProjectViewModel` issue separately, restore a concrete simulator, then run the adapter test suite before any persistent-store migration.

### 2026-07-10 Parallel bridge verification

- Changed: tightened `MemoraNativeModule` diagnostics so `isRealDataConnected` and `persistenceScope = shared-swiftdata` require both the audio reader and mutator to report `swiftdata`.
- Changed: updated `BRIDGE_CONTRACT.md` and this migration plan to document the two-sided verification rule.
- Verification: RN iOS `xcodebuild` passed; `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Decision: keep the RN host on `native-files` / `app-sandbox` until a reader and mutator backed by the same verified SwiftData store are injected together.
- Next: implement the host-side shared `ModelContainer` ownership path, with App Group and store migration still gated behind explicit backup/rollback validation.

### 2026-07-10 Test target recovery

- Changed: added `Memora/Core/ViewModels/CreateProjectViewModel.swift` because `CreateProjectViewModelTests.swift` referenced a missing production type.
- Behavior: trims project titles, rejects empty titles, preserves the first configured repository, reports missing repository/save errors, and clears errors after success.
- Verification: Memora `build-for-testing` passed with `TEST BUILD SUCCEEDED`; shared package `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Environment note: the test bundle is now compilable, but actual test execution still needs a concrete CoreSimulator device.
- Next: execute the full iOS suite on a usable simulator and start the host-side `ModelContainer`/shared-store injection spike in a separate native-data batch.

### 2026-07-10 Shared store path contract adoption

- Changed: `Memora/App/MemoraApp.swift` now uses `MemoraSharedStoreLocation.storeURL(in:)` for the existing Application Support store path.
- Safety: the resolved path remains `Application Support/Memora/Memora.store`; no App Group entitlement, store copy, or migration was performed.
- Verification: Memora iOS build passed; RN iOS build passed; shared package `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Environment note: `xcrun simctl create` still fails because the device becomes stuck in creation state, so runtime test execution remains unavailable.
- Next: implement and test the RN host-side `ModelContainer` ownership seam without enabling shared persistence prematurely.

### 2026-07-10 RN shared store bridge adapter

- Changed: added `apps/mobile-expo/ios/MemoraRN/MemoraSharedStoreBridgeAdapters.swift`.
- Changed: added `MemoraNativeBridgeBootstrap.configureSharedAudioStore(...)`, which installs the same adapter instance as both reader and mutator so diagnostics cannot report a half-wired shared boundary.
- Safety: the adapter is not invoked by `configureDefaults()`; RN remains on native-file storage and `app-sandbox` persistence until a real host SwiftData store is explicitly passed in.
- Verification: RN iOS build passed; shared package `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Next: build a host-side factory that owns the SwiftData `ModelContainer`, then pass its repository adapter into this seam only after store migration/rollback approval.

### 2026-07-10 SwiftData host factory

- Changed: added `MemoraSharedStoreHostFactory` to create `MemoraSharedAudioFileStoreAdapter` from an existing host `ModelContainer`.
- Boundary: the factory owns no global state and is not called during app startup; it only makes the host-side adapter available for an explicit integration step.
- Verification: Memora iOS build passed; RN iOS build passed; shared package `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Next: choose whether the two targets will share a framework/package model graph or use an explicitly migrated App Group store before crossing this adapter into RN.

### 2026-07-10 Shared adapter error hardening

- Changed: invalid UUIDs now fail explicitly during shared-store upsert; empty rename titles now throw a descriptive error.
- Reason: prevent silent data loss or accidental replacement with a generated fallback UUID at the native boundary.
- Verification: RN iOS build passed; Expo `npm run typecheck` passed; `git diff --check` passed.
- Next: add a dedicated RN host test target for adapter conversion and mutation behavior before enabling the adapter with real SwiftData.

### 2026-07-10 Shared store source diagnostics

- Changed: `MemoraSharedAudioFileStore` now requires `sourceDescription`; `MemoraInMemoryAudioFileStore` reports `mock`, and the RN bridge adapter forwards the injected store's source description.
- Safety: injecting the in-memory contract probe can no longer make the RN bridge report `swiftdata` or `shared-swiftdata`.
- Verification: Memora iOS build passed; RN iOS build passed; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Next: add a dedicated RN host test target and connect only a verified SwiftData-backed store to `configureSharedAudioStore(...)`.

### 2026-07-10 RN host adapter test target

- Changed: added `apps/mobile-expo/ios/MemoraRNTests/MemoraSharedStoreBridgeAdapterTests.swift`.
- Changed: registered `MemoraRNTests` in the RN Xcode project and existing scheme, inheriting the Expo/CocoaPods build configuration.
- Coverage: mock source preservation, DTO field conversion, rename/delete mutation, invalid UUID rejection, and empty-title rejection.
- Verification: RN workspace `build-for-testing` passed with `TEST BUILD SUCCEEDED`; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Blocker: actual unit test execution still requires a concrete CoreSimulator device; device creation currently stalls in CoreSimulator.
- Next: execute the RN host suite on a working simulator, then wire only a verified SwiftData store into the shared adapter.

### 2026-07-10 Parallel validation gate

- Verification: `xcodebuild -project apps/mobile-expo/ios/MemoraRN.xcodeproj -list` recognizes both `MemoraRN` and `MemoraRNTests`.
- Verification: RN workspace `build-for-testing` passed with `TEST BUILD SUCCEEDED`; shared `swift test` passed with 6 tests; Expo `npm run typecheck` passed; `git diff --check` passed.
- Environment note: runtime unit-test execution remains blocked because CoreSimulator has runtimes but no usable concrete devices; device creation stalls in the creation state.
- Next: run the already-compiled RN host tests when a simulator becomes available, then begin the explicit SwiftData/App Group ownership decision.

### 2026-07-10 Physical device build and install

- Changed: added the existing Memora development team to the RN host target so a paired physical iPhone can be used for Dev Client validation.
- Verification: `xcodebuild -workspace apps/mobile-expo/ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'id=9A1B4213-7A1A-5663-8456-1FBEE0E724C8' -allowProvisioningUpdates build` passed with `BUILD SUCCEEDED`.
- Verification: `xcrun devicectl device install app` installed `com.anonymous.memora-rn` on the paired iPhone.
- Blocker: launch was denied because the device was locked. Unlock the iPhone, then retry launch and inspect the RN bridge/settings screen.
- Next: perform real-device recording/import, bridge diagnostics, and native-file persistence checks after unlock.

### 2026-07-10 Physical device launch and Metro connection

- Verification: unlocked paired `Ken’s iPhone` and launched `com.anonymous.memora-rn` successfully through `devicectl`.
- Verification: Metro received the iOS bundle request from the physical device and completed `expo-router/entry.js` bundling for 1,350 modules on port `8089`.
- Verification: console launch reached React Native JavaScript evaluation without a native crash; standard Expo background-fetch/remote-notification configuration warnings were observed.
- Current state: the RN app was relaunched without console attachment and remains running on the physical device.
- Next: inspect the live device UI and exercise Home recording/import plus Settings Bridge diagnostics; then validate native-file persistence across relaunch.

### 2026-07-10 Home visual-parity pass

- Changed: removed the scaffold-like marketing headline and large action cards from the RN Home screen.
- Changed: aligned the first-pass visual language with SwiftUI V6: white background, `全ファイル` title, compact search/settings header, connection row, black filter pills, red record action, and low-contrast list separators.
- Files touched: `apps/mobile-expo/src/design/tokens.ts`, `apps/mobile-expo/src/components/Screen.tsx`, `apps/mobile-expo/src/components/Section.tsx`, `apps/mobile-expo/src/components/AudioFileCard.tsx`, `apps/mobile-expo/src/screens/HomeScreen.tsx`.
- Verification: `npm run typecheck` passed; Metro re-bundled the iOS client; `git diff --check` passed. `npm run lint` is unavailable because no lint script exists in `apps/mobile-expo/package.json`.
- Decision: this is the beginning of design parity work, not a claim of full visual completion. Home still needs screenshot-based spacing review on the physical iPhone.
- Next: capture/inspect the real Home screen, then move the remaining action menu toward the V6 bottom FAB and continue with File Detail/Ask AI/Settings shell alignment.

### 2026-07-10 File Detail visual-parity pass

- Changed: replaced the RN dark hero card with a V6-style white detail shell.
- Changed: added back navigation, compact share/more header affordances, date/duration subtitle, status/source metadata, underline tabs, flatter panels, and the file-scoped Ask AI bar.
- Files touched: `apps/mobile-expo/src/components/Screen.tsx`, `apps/mobile-expo/src/screens/FileDetailScreen.tsx`.
- Verification: `npm run typecheck` passed; Metro re-bundled the iOS client; `git diff --check` passed.
- Decision: share and more are visual affordances for now; the next native-boundary pass must connect them to export and file actions instead of inventing RN-only behavior.
- Next: align Ask AI and Settings shells, then perform screenshot-based review on the unlocked physical iPhone.

### 2026-07-10 Ask AI visual-parity pass

- Changed: removed the scaffold subtitle and large segmented control treatment.
- Changed: added compact scope underline tabs, flatter message bubbles, subdued source chips, and a bordered white input composer with black send action.
- Files touched: `apps/mobile-expo/src/screens/AskAIScreen.tsx`.
- Verification: `npm run typecheck` passed; Metro received the updated iOS bundle request; `git diff --check` passed.
- Decision: scope/history/query behavior remains in the existing RN facade; this pass only changes presentation.
- Next: align Settings and bottom action/FAB behavior, then run the physical-device visual review.

### 2026-07-10 Settings visual-parity pass

- Changed: removed the large settings explanation card and reduced each group to V6-style section label plus compact rows.
- Changed: selected transcription/provider controls now use the V6 black accent; Bridge diagnostics remain visible as status rows.
- Files touched: `apps/mobile-expo/src/screens/SettingsScreen.tsx`.
- Verification: `npm run typecheck` passed; Metro received the updated iOS bundle request; `git diff --check` passed.
- Decision: settings values still flow through the existing `MemoraNative` DTO facade; no secret or Swift Keychain ownership moved into RN.
- Next: implement the Home bottom action/FAB behavior and inspect the four major screens on the physical iPhone.

### 2026-07-10 Home bottom FAB pass

- Changed: extended `Screen` with an optional fixed footer accessory.
- Changed: Home now uses a V6-style red circular FAB that expands to `録音` and `取り込み` menu actions; existing bridge handlers and optimistic refresh behavior are unchanged.
- Files touched: `apps/mobile-expo/src/components/Screen.tsx`, `apps/mobile-expo/src/screens/HomeScreen.tsx`.
- Verification: `npm run typecheck` passed; `git diff --check` passed; Metro remains connected to the physical-device client.
- Decision: the FAB is Home-only so File Detail, Ask AI, and Settings retain their own shell layouts; the Expo tab bar remains the navigation owner.
- Next: inspect the physical device for overlap and spacing, then complete the first visual-review loop across all four screens.

### 2026-07-10 File Detail action wiring

- Changed: connected both File Detail share affordances to React Native's iOS `Share` sheet with the file title and summary.
- Changed: connected the more affordance to an action alert that opens the existing bridge-file rename flow when supported.
- Files touched: `apps/mobile-expo/src/screens/FileDetailScreen.tsx`.
- Verification: `npm run typecheck` passed; Metro received the updated iOS bundle request; `git diff --check` passed.
- Decision: export/audio-file actions remain outside this pass; the share sheet is text-based until the native export contract is selected.
- Next: validate share/rename on the physical device and inspect the full four-screen visual pass.

### 2026-07-10 Parallel validation gate

- Changed: no product files changed in this gate; independent validation tracks were run concurrently.
- Verification: Expo `npm run typecheck` passed; `npx expo export --platform web` passed with 891 modules; RN workspace `build-for-testing` passed with `TEST BUILD SUCCEEDED`; `Packages/MemoraSharedData` `swift test` passed with 6 tests; `git diff --check` passed.
- Decision: the remaining work is now primarily real-device UI review and explicitly gated native-boundary choices, not basic compilation recovery.
- Next: exercise Home FAB, File Detail share/rename, Ask AI send, Settings persistence, and Bridge diagnostics on the unlocked physical iPhone.

### 2026-07-10 Physical device re-verification and CoreSimulator root-cause investigation

- Changed: no product/RN source files changed this session. Confirmed the existing physical-device Dev Client build still installs, launches, and connects to Metro end to end.
- Verification: `xcodebuild -workspace apps/mobile-expo/ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'id=9A1B4213-7A1A-5663-8456-1FBEE0E724C8' -allowProvisioningUpdates build` passed with `BUILD SUCCEEDED`. `xcrun devicectl device install app` and `xcrun devicectl device process launch` both succeeded against the paired `Ken's iPhone` (`9A1B4213-7A1A-5663-8456-1FBEE0E724C8`), no lock-screen blocker this time. `lsof -nP -iTCP:8089` showed 5 `ESTABLISHED` sockets between the phone's LAN IP (`192.168.86.130`) and the running Metro process (`192.168.86.26:8089`) immediately after launch, which is concrete evidence the JS bundle loaded, not just that the native binary is alive. `xcrun devicectl device info processes` confirmed the `MemoraRN` process stayed running afterward. The established sockets later dropped, most likely from the device screen locking/backgrounding the app; this is expected iOS behavior and was not investigated further.
- Full validation suite: `npm run typecheck` passed; `xcodebuild ... -destination 'generic/platform=iOS Simulator' build-for-testing` passed with `TEST BUILD SUCCEEDED`; `Packages/MemoraSharedData` `swift test` passed with 6 tests; `npx expo export --platform web` passed; `git diff --check` clean.
- CoreSimulator investigation: device creation once failed with `Device was allocated but was stuck in creation state`; the log showed a sample-content-copy permission error in the externalized device-data directory.
- Historical diagnosis: externalizing CoreSimulator data initially left its service unable to copy protected sample content even though shell writes worked. Ownership and Full Disk Access were checked; later validation succeeded. Treat this as environment history rather than an active application blocker.
- Decision: stop spending further time on this environment issue for now. It is orthogonal to the RN migration and does not block physical-device work.
- Next: if simulator screenshots become worth unblocking again, try (a) pointing `DeviceSetPath` at an internal-disk location temporarily (`xcrun simctl --set <internal-path> create ...`) to confirm the external volume specifically is the blocker, or (b) freeing internal disk space so CoreSimulator can live on the primary volume group as Apple expects, rather than continuing to chase TCC/ownership settings on the external volume.
- Follow-up: a manual sample-content copy succeeded, isolating the original issue to the simulator service rather than ordinary filesystem ownership.
- **RESOLVED (2026-07-10, later same day):** The real root cause was that TCC's Full Disk Access grant for `/Applications/Xcode.app` does not propagate to two separate embedded XPC services that CoreSimulator spawns independently: `com.apple.CoreSimulator.SimulatorTrampoline` and `com.apple.CoreSimulator.CoreSimulatorService` (queried directly from `/Library/Application Support/com.apple.TCC/TCC.db`, table `access`, service `kTCCServiceSystemPolicyAllFiles` — both showed `auth_value=0`/denied even after Xcode.app itself showed `auth_value=2`/allowed, and even after a full Mac restart). Fix: in System Settings → Privacy & Security → Full Disk Access, drag-and-drop both `.xpc` bundles directly from Finder (the `+` picker dialog does not surface them) — paths: `/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/XPCServices/SimulatorTrampoline.xpc` and `.../XPCServices/com.apple.CoreSimulator.CoreSimulatorService.xpc` — then toggle both on and kill the running processes (`pgrep -f "SimulatorTrampoline|CoreSimulatorService"` → `kill -9`) so they respawn with the new grant. After this, `xcrun simctl create` succeeded immediately (no restart needed once both XPC services are correctly granted).
- Created a dedicated iPhone 17 Pro (iOS 26.5) simulator for RN validation.
- Mid-session the external `HIKSEMI` volume briefly disconnected (surfaced as the project directory "not existing"); it reconnected on its own and no data was lost. Cause not fully diagnosed — likely a USB/dock hiccup around the Mac restart. Worth noting for future sessions: if `git status` or file reads suddenly fail with "no such file or directory" on this project, check `diskutil list` for the HIKSEMI volume before assuming anything is broken.
- First simulator boot took several attempts: `xcrun simctl install` hung indefinitely (0% CPU, genuinely deadlocked, not just slow) after a boot that never progressed past 6 launchd services. Fix was `simctl shutdown` + kill all CoreSimulator processes + fresh `simctl boot` + `simctl bootstatus -b` (which showed real progress through data-migration stages and finished cleanly in ~2m26s) before attempting install again — after that, install/launch worked normally and quickly.
- Established a working automated-screenshot-and-tap QA loop for this iOS Simulator entirely from the CLI: `xcrun simctl io <udid> screenshot <path>` for capture, and for input, `osascript -e 'tell application "System Events" to tell process "Simulator" to click at {x, y}'` for taps (requires the automation source — in this session, `/Applications/Claude.app`, found via `ps -p $$` parent-chain, not `Terminal.app` — to have Accessibility permission granted in System Settings; also required drag-and-drop of both entries since the running process's actual TCC client ID, e.g. `com.anthropic.claude-code` and `com.anthropic.claudefordesktop`, both needed the toggle). `cliclick` (installed via `brew install cliclick`) was used for swipe/scroll gestures via multi-step `dd`/`dm`/`du` sequences, though scroll gestures did not reliably register in this session and are still unresolved.
- Coordinate mapping for taps: get the Simulator window's content frame via `osascript -e 'tell application "System Events" to tell process "Simulator" to tell window 1 to return {position of group 1, size of group 1}'`, which returns `{winX, winY, winW, winH}` in macOS points. Given a target point `(px, py)` in the `simctl io screenshot` PNG (whose pixel dimensions are the device's native resolution, e.g. 1206×2622 for iPhone 17 Pro), the click point is `screenX = winX + px / (imgW / winW)`, `screenY = winY + py / (imgH / winH)`. In this session `winW=371, winH=807, imgW=1206, imgH=2622`, giving a scale factor of ~3.25. Empirically the top underline-tabs row calibrated correctly on the first try; the bottom tab bar needed manual recalibration (~200pt lower than the naive proportional calculation predicted) — recommend verifying any new tap target with a screenshot-and-adjust pass rather than trusting the formula blindly near the edges.
- Live-verified with real screenshots (not claims) via this simulator, connected to a freshly restarted Metro (`cd apps/mobile-expo && npx expo start --dev-client --port 8089`; the original Metro session from earlier in the day had died in the Mac restart):
  - **Home**: matches V6 white/black/red styling, `全ファイル` title, filter pills, file row, FAB. FAB expand-to-menu (`録音`/`取り込み` with a black X to close) works and does not overlap the Expo tab bar — confirmed both collapsed and expanded states.
  - **File Detail**: reachable via tapping a file card. Confirmed a real visual bug: **the header renders twice** — Expo Router's native-stack header (`< (tabs)` back pill + `ファイル詳細` title) appears above a second, custom in-content header (its own `<` back chevron + the file title `Native bridge sample`). This needs a fix (likely hide the native-stack header via route options, since the screen already renders its own). Below that, share/summarize buttons, underline tabs (Summary/Transcript/Memo), and the file-scoped question bar all render correctly per V6 style.
  - **Ask AI**: scope underline tabs (ファイル/プロジェクト/全体) switch correctly and each keeps independent state — confirmed by tapping through all three; file/project scopes show seeded conversation history, global scope shows a proper empty state (icon + `まだ質問はありません` + description). Composer bar and send button render correctly.
  - **Settings**: dense grouped rows confirmed — Transcription mode (Local/API) and Summary provider (Gemini/OpenAI/DeepSeek/Local) segmented controls with black selected state, SpeechAnalyzer toggle, and a Bridge-diagnostics-style status section (`文字起こしと AI`, `デバイス連携`) with colored status dots (green = connected/active, amber = flagged/experimental) for Transcription mode, Summary provider, SpeechAnalyzer, PLAUD import, Omi preview. Did not confirm scroll-to-bottom (gesture automation didn't register) — remaining Settings content below `Omi preview` is still unverified.
- Next: fix the File Detail double-header bug first (quick, well-scoped). Then continue the V6 spacing/polish pass using this now-working screenshot loop instead of guessing. Investigate the scroll-gesture reliability issue if deeper Settings/Transcript-tab content needs visual review.

### 2026-07-10 File Detail double-header fix

- やること: File Detailの二重ヘッダーバグを修正する。変更するファイル: `apps/mobile-expo/app/_layout.tsx`。変更しないファイル: `FileDetailScreen.tsx`(既に正しい独自ヘッダーを描画しているため)。
- Root cause: `FileDetailScreen` renders its own full header via the `Screen` component (`headerLeading`/`title`/`headerAccessory`), but the root `Stack.Screen` for `file/[id]` in `app/_layout.tsx` still had the default Expo Router native-stack header enabled with `title: 'ファイル詳細'`, so both rendered stacked on top of each other. Every other screen using `Screen` lives inside the `(tabs)` group, which already has `headerShown: false` at the group level — `file/[id]` is a stack push outside that group and was missing the same treatment.
- Fix: changed the `file/[id]` `Stack.Screen` options in `apps/mobile-expo/app/_layout.tsx` from `{ title: 'ファイル詳細', presentation: 'card' }` to `{ headerShown: false, presentation: 'card' }`.
- Verification: `npm run typecheck` passed. Re-opened File Detail in the `Memora RN Test` simulator via the automated screenshot+tap loop — confirmed only one header renders now (custom back chevron, file title, share/more icons), and confirmed the back button still navigates to Home correctly. `apps/mobile-expo` is untracked in git as a whole, so `git diff`/`git diff --check` show nothing for this change by design; `git status --short apps/mobile-expo/app/_layout.tsx` shows `?? apps/mobile-expo/app/_layout.tsx` (part of the pre-existing untracked app directory).
- Next: continue the V6 spacing/polish pass (Home file-row/FAB spacing, File Detail padding, Ask AI composer keyboard behavior, Settings density) using the now-working screenshot loop. Resolve the scroll-gesture automation gap if deeper content needs visual review.

### 2026-07-10 File Detail token fixes + Ask AI plain-document rewrite

- やること: SwiftUI V6ソース(`V6FileDetailView.swift`, `AskAIView.swift`, `AskAI+Subviews.swift`, `MessageBubbleView.swift`)の実測値を基に、File DetailとAsk AIの余白・書体・メッセージ表示スタイルをV6に合わせる。変更するファイル: `apps/mobile-expo/src/screens/FileDetailScreen.tsx`, `apps/mobile-expo/src/screens/AskAIScreen.tsx`, `apps/mobile-expo/src/design/tokens.ts`。変更しないファイル: ネイティブブリッジ層、`Screen.tsx`のレイアウト構造(titleをoptionalにしただけ)。
- Investigated V6 source directly instead of guessing from screenshots: `Memora/Views/V6/V6FileDetailView.swift` (header icon touch targets are 40×40pt, title is `fontSize 24 bold tracking -0.24 lineLimit(1)`, tab bar uses `HStack(spacing: 24)`), `Memora/Views/AskAIView.swift` + `AskAI+Subviews.swift` + `MessageBubbleView.swift` (scope tabs also `spacing: 24`; **critically, V6 Ask AI messages are explicitly NOT rounded chat bubbles** — the source code comment says so directly: user questions render as plain small grey text (`12.5pt medium, V6Color.muted`, full width, no background), assistant answers render as plain body text (`15pt`) + citation chips + a bottom divider line, with no bubble background or `maxWidth` constraint on either side).
- File Detail bug found via screenshot: the title was rendering twice — once from `Screen`'s own 32pt header title, once from `FileDetailScreen`'s own 24pt `heroTitle` block — because `Screen`'s `title` prop was always passed even though `FileDetailScreen` already builds its own richer title block (with inline rename). This produced the two-line title wrap visible in earlier screenshots.
- Changed `apps/mobile-expo/src/components/Screen.tsx`: made `title` optional and conditionally rendered, so screens with their own custom title block (like File Detail) can omit it without leaving a stray empty header row. No other screen's behavior changes since they all still pass `title`.
- Changed `apps/mobile-expo/src/screens/FileDetailScreen.tsx`: stopped passing `title={file.title}` to `Screen` for the main content state (kept `subtitle`); fixed `headerIcon`/`backButton` to 40×40pt touch targets (was 34×30/34×28); fixed `heroTitle` to `fontWeight: '700'` (was `'900'`) with `letterSpacing: -0.24` and `numberOfLines={1}` (was allowed to wrap to 2 lines); fixed `tabs` gap from `spacing.lg` (16) to `24` to match V6's `HStack(spacing: 24)`.
- Changed `apps/mobile-expo/src/screens/AskAIScreen.tsx`: replaced the rounded-bubble message rendering (`maxWidth: '94%'`, `alignSelf` left/right, black/bordered backgrounds) with V6's plain-document style — user questions are plain `12.5pt` muted text at full width, assistant answers are plain `15pt` body text followed by source chips (now with a small document icon, bordered `faint` background, `10.5pt` label, matching `MessageBubbleView.swift`) and a bottom divider line per message block; fixed `scopeBar` tab gap from `spacing.lg` (16) to `24`.
- Changed `apps/mobile-expo/src/design/tokens.ts`: added `textMutedLight: '#8E8EA0'` to exactly match `V6Color.muted`, since the existing `textSubtle` (`#6E6E80`) actually corresponds to `V6Color.tertiary`, not `V6Color.muted`. Used for the Ask AI user-question text color.
- Scope decision (explicitly deferred): Settings' information architecture does not match V6 at all — V6's `settingsScreen` is a product settings screen (Account/Device/Storage/Notifications/Integrations/AI model/Delete data/Logout), while the current RN Settings screen is a transitional bridge-diagnostics screen (Transcription mode/Summary provider/SpeechAnalyzer + Bridge status). The user explicitly chose to defer this to a separate decision rather than address it in this spacing pass — do not silently redesign Settings' structure without that explicit go-ahead.
- Verification: `npm run typecheck` passed after each change. Verified all changes visually via the simulator screenshot+tap loop: File Detail now shows a single non-wrapping title with correct back/share/more touch target sizing and wider tabs; Ask AI now renders questions/answers in the plain-document style with no bubble backgrounds, source chips have icons, and scope-tab switching (ファイル/プロジェクト/全体) still works correctly with the wider tab spacing. `apps/mobile-expo` is untracked in git so `git diff --check` shows nothing for these changes by design; confirmed via `git status --short`.
- Next: Home file-row/connection-row spacing pass (note: V6's SwiftUI Home puts the device-connection row *above* the big title, while RN currently puts it *below* — this ordering difference was found but not fixed this session since it requires restructuring `Screen`'s header composition; flag for a future decision). Then Settings IA decision (see above).

### 2026-07-10 Scroll-gesture automation fixed + full Settings verification

- Root cause of the earlier scroll-gesture failures: `cliclick`'s `dd`/`dm`/`du` drag sequence needs an explicit `m:x,y` (move) command *before* the initial `dd:` (mouse-down), plus a real wait (`w:100`, ~100ms) between every intermediate `dm:` step. Without the leading move and with steps too close together in time, the Simulator's touch-translation layer did not recognize the sequence as a pan/scroll gesture and simply dropped it (no error, just no visible effect) — this is why earlier attempts silently did nothing rather than failing loudly.
- Working command shape: `cliclick m:X,Y dd:X,Y w:100 dm:X,Y2 w:100 dm:X,Y3 w:100 ... du:X,Yfinal`.
- Used this to scroll all the way through Settings and confirm the full Bridge diagnostics list renders correctly below `Omi preview`: `Generic BLE` (Bridge pending, gray dot), a `REACT NATIVE 移行` section with `Expo mock screens` / `Native bridge` / `Cutover` status rows, then a `BRIDGE` section with `Module` / `Platform` / `Audio source` / `Mutation source` / `Recording source` / `Settings source` / `Knowledge source` / `Summary source` / `Persistence source` — all with correctly colored status dots (green/amber/gray) and consistent row spacing/dividers all the way to the end of the scroll view. No visual issues found in this previously-unverified portion.
- This closes out the "Settings content below Omi preview is unverified" gap noted earlier this session.
- Final validation pass: `npm run typecheck` passed; `Packages/MemoraSharedData` `swift test` passed with 6 tests; RN workspace `build-for-testing` on `generic/platform=iOS Simulator` passed with `TEST BUILD SUCCEEDED`; `git diff --check` clean (all RN changes remain in the untracked `apps/mobile-expo` directory by design).
- Session summary: this was an unusually long session dominated by environment troubleshooting (CoreSimulator Full Disk Access root-caused and fixed, external volume disconnect/reconnect scare) before real feature work became possible. Net result: a fully working simulator-based screenshot+tap QA loop now exists for future sessions, one real bug fixed (File Detail double header), and one real visual/behavioral mismatch fixed (Ask AI bubble-vs-plain-document style). Two genuine design decisions were surfaced and explicitly deferred rather than guessed at (Home header ordering, Settings information architecture) — a future session should raise these with the user before touching them.

### 2026-07-10 Home header reorder (connection row above title, matching V6)

- やること: user gave an explicit "進めてください" go-ahead after the previous summary listed this as deferred. Implemented the Home connection-row/title reorder to match V6's `homeScreen` layout (`Memora/Views/V6/V6AppShellView.swift` lines ~133–190): a top row with the device-connect control on the left and search/settings icons on the right, then the big title on its own row below. Did **not** touch the separately-deferred Settings IA question — that one still requires product decisions (new sections, new data sources) that a pure layout reorder does not.
- Changed `apps/mobile-expo/src/components/Screen.tsx`: added an optional `topRow?: ReactNode` prop, rendered above the existing `titleRow` inside the same header container. No other screen passes it, so Ask AI/Settings/File Detail are unaffected.
- Changed `apps/mobile-expo/src/screens/HomeScreen.tsx`: moved the search/settings icon `Pressable`s out of `headerAccessory` and, together with the existing connection-status row, into a new `topRow` (a `View` with `flexDirection: 'row', justifyContent: 'space-between'`) rendered above the `全ファイル` title. Removed the now-unused `connectionSpacer` style (was only there to fill space in a row that no longer needs it) and the standalone `connectionRow` block that used to be the first child under the title.
- Verification: `npm run typecheck` passed. Verified visually via the simulator screenshot+tap loop: Home now shows connection status + search/settings icons on one row, `全ファイル` title below it, matching V6's layout order. Confirmed the search icon still routes to `/ask-ai` and the settings icon still routes to `/settings` (tapped the relocated gear icon and landed on the Settings screen). `git diff --check` clean (untracked app dir, confirmed via `git status --short`).
- Next: only the Settings IA decision remains open from this session's findings. Continue further V6 polish only after that's resolved, or pick up other independent workstreams (W4 real feature wiring, native export/settings boundary) per the top-level migration plan.

### 2026-07-10 Settings V6 information architecture added (mock data), Bridge diagnostics kept

- やること: user was asked explicitly (again) whether to build out V6's product Settings IA now; answer was "V6の構成をモックデータで追加し、Bridge診断は残す" (add V6's structure with mock data, keep the Bridge diagnostics section). 変更するファイル: `apps/mobile-expo/src/screens/SettingsScreen.tsx`, `apps/mobile-expo/src/design/tokens.ts`。変更しないファイル: native bridge/settings persistence layer — no new data actually flows anywhere; every new row is either static display text or shows a "not yet connected" alert on press.
- Added 8 new V6-matching groups **above** the existing bridge-diagnostics content, read directly from `Memora/Views/V6/V6AppShellView.swift` lines ~553–662 (`settingsScreen`, `V6SettingsGroup`, `V6SettingsRow`, `V6SettingsBadgeRow`): アカウント (未設定 / プラン Free badge), デバイス (PLAUD/Omi デバイス管理, 未接続), ストレージ (添付の保存先, この端末), 通知 (プッシュ通知 toggle — local React state only, not persisted), 連携 (Notion に書き出す / ChatGPT に共有, both 未接続), 文字起こし・要約 (AI モデル — reads the existing `summaryProvider` setting so it's not pure mock, 要約テンプレート — 議事録 hardcoded), その他 (データを削除, destructive/red), アカウント操作 (ログアウト, destructive/red).
- New local components in `SettingsScreen.tsx`: `SettingsGroupCard` (group label + `faint`-background rounded card, matches `V6SettingsGroup`), `SettingsRow` (title + optional right-aligned value + chevron, matches `V6SettingsRow`), `SettingsBadgeRow` (title + colored pill badge + chevron, matches `V6SettingsBadgeRow`). All ported with exact V6 numeric values (row padding 13v/14h, title 15pt, value 13pt, badge 11pt bold, group label 12pt semibold).
- Since none of these rows have a real destination or backing data source yet, every row's `onPress` shows a single shared `Alert.alert('準備中', ...)` explaining the bridge isn't connected for that action yet, rather than silently doing nothing or pretending to navigate somewhere. This keeps the mock honest about its current state instead of implying finished functionality.
- Added `colors.faint` (`#F7F7F7`, matches `V6Color.faint` exactly) to `apps/mobile-expo/src/design/tokens.ts` for the new card backgrounds.
- Verification: `npm run typecheck` passed. Verified visually via the simulator screenshot+tap loop: all 8 new groups render in the correct V6 order and style, the existing "設定を編集" bridge controls and "文字起こしと AI" / "デバイス連携" / "React Native 移行" / "Bridge" diagnostic sections still render unchanged directly below them, and tapping "データを削除" correctly shows the "準備中" alert (screenshot-confirmed, not assumed). `git diff --check` clean (untracked app dir, confirmed via `git status --short`).
- Decision record: this intentionally does **not** wire any of the new rows to real backend/bridge behavior (no actual account system, device pairing flow beyond what already exists, storage plan, push notification permission request, Notion/ChatGPT OAuth, or destructive data deletion). That would be new W4 feature-wiring scope, not a V6 visual-parity pass. If a future session wants to make any of these rows functional, treat each one as its own scoped task with its own native-boundary decision, the same way audio file read/mutate/recording/settings/knowledge/summary were each their own registry.
- Next: no more items from this session's V6 review remain undecided. Resume from the top-level migration plan's W4/W5 workstreams, or start a fresh V6 comparison pass on Home file rows / any screens not covered this session (Recording modal, Generation Progress, Onboarding/Login/Paywall — none of these have RN implementations yet per the Migration Scope table).

### 2026-07-10 File Detail Transcript/Memo tab gap analysis (found, not fixed — needs a scope decision)

- User asked to keep reviewing other RN screens/states against V6. Since the app only has 4 real routes (Home, File Detail, Ask AI, Settings — confirmed via `find apps/mobile-expo/app -iname "*.tsx"`; `PreviewIndexScreen` is a dev-only route index, not a V6-comparable screen), this pass checked previously-unvisited **states within** existing screens: Home's プロジェクト/ライフログ filter tabs, and File Detail's Transcript/Memo tabs.
- Home プロジェクト/ライフログ empty states: fine, no changes needed. Both show an honest "not yet available" empty state (`プロジェクト機能は SwiftUI 版との接続後に追加します。` / `ライフログの記録がここに表示されます。`) — screenshot-confirmed, consistent with how this codebase already handles unbuilt functionality.
- **Found a real gap, not fixed**: read `Memora/Views/FileDetail/TranscriptTab.swift` and `Memora/Views/FileDetail/MemoTab.swift` directly. Both are substantially more than a styling difference from the current RN implementation:
  - Transcript: V6 has a full audio player bar (play/pause button, elapsed/total time, tap-to-cycle playback speed, a draggable seek progress bar) plus tappable speaker/timestamp/text segments that seek playback when tapped. RN's current Transcript tab only shows a static `TranscriptionProgressCard` mock ("Native bridge event preview" / "Swift STT event stream に差し替える前の mock 進捗です", 0% progress, 開始/キャンセル buttons) with no real audio playback at all.
  - Memo: V6 has a tap-to-edit `TextEditor` with a 保存 button, plus a `PhotosPicker`-based photo attachment gallery (add/preview/reorder). RN's current Memo tab only renders `file.memo` as static read-only text lines — no editing, no photo attachment.
  - Both gaps require new native bridge surface area that doesn't exist yet (audio playback control — play/pause/seek/currentTime/duration/rate — and a photo picker + attachment storage contract), not just RN-side UI work. Building fake/non-functional player or editor controls to visually match V6 would be actively misleading (worse than a plain "not yet available" state), so this was **not** attempted without a scope decision.
- Decision needed from the user before any implementation: (a) build these as new native-bridge-backed features (its own scoped native + RN work, similar in size to the existing recording/import bridge), (b) build V6-styled but explicitly-disabled/placeholder UI (same "準備中" pattern used for the new Settings rows) so the visual shell exists without pretending to work, or (c) leave both tabs as-is for now and prioritize something else.
- Next: raise this finding with the user; do not build audio playback or photo attachment UI without an explicit choice among the above.

### 2026-07-10 Real native playback + memo/photo bridge implemented

- やること: implement Transcript-tab audio playback and Memo-tab text/photo attachment as real native-bridge features (user's explicit choice: "本物のネイティブブリッジ機能として実装する", same scale as the existing recording/import bridge). 変更するファイル: new Swift files in `apps/mobile-expo/modules/memora-native/ios/` (`MemoraPlaybackDTO.swift`, `MemoraMemoDTO.swift`), `MemoraNativeModule.swift`, `MemoraNativeBridgeBootstrap.swift`, `MemoraAudioFileDTO.swift` (added one lookup helper), RN `src/native/MemoraNative.types.ts` + `MemoraNative.ts`, new `src/features/playback/usePlayback.ts`, new `src/features/memo/useMemoNotes.ts`, new `src/components/PlayerBar.tsx`, `src/screens/FileDetailScreen.tsx`, `src/design/tokens.ts` (added `faint`), `app.json` + generated `ios/MemoraRN/Info.plist` (added `NSPhotoLibraryUsageDescription`), installed `expo-image-picker`. 変更しないファイル: any protected STT files, `AIService.swift`, `CoreDTOs.swift` — transcript segments remain empty/unimplemented since that requires real STT output, which stays out of scope.
- Playback bridge design, following the exact registry/protocol/DTO pattern already used for recording/import: `MemoraPlaybackStatusDTO` (audioFileId, isPlaying, position, duration, rate) + `MemoraPlaybackControlling` protocol (`load`/`play`/`pause`/`seek`/`setRate`/`getStatus`) + `MemoraNativePlaybackRegistry` + `MemoraAVAudioPlaybackController`, a real `AVAudioPlayer`-backed implementation that looks up the recorded file's path via a new `MemoraNativeAudioFileMetadataStore.filePath(forId:)` helper. Files that have no real audio (e.g. the `native-sample` placeholder) correctly throw `MemoraPlaybackError.fileNotFound`, which the existing `withNative` catch-and-fallback pattern in `MemoraNative.ts` turns into a JS-simulated 12-second fallback player — consistent with how every other bridge method in this codebase already degrades (not a new inconsistency).
- Memo/photo bridge: `MemoraPhotoAttachmentDTO` + `MemoraMemoHandling` protocol (`getMemoDraft`/`saveMemoDraft`/`listPhotoAttachments`/`addPhotoAttachment`/`deletePhotoAttachment`) + `MemoraNativeMemoRegistry` + `MemoraNativeFileMemoStore`, a real JSON-backed store (`Documents/MemoraNativeMetadata/memo-notes.json`) keyed by audioFileId, with photo files copied into `Documents/MemoraNativeMemoPhotos/<audioFileId>/`.
- RN UI: `PlayerBar.tsx` matches `TranscriptTab.swift`'s `playerBar` values (38×38 circular play/pause, monospace elapsed/total time, speed-cycle pill, 3px tap-to-seek track) and now sits above the existing mock `TranscriptionProgressCard` in the Transcript tab (segments list remains the honest "no transcript yet" state since STT is out of scope). The Memo tab was rewritten from static bullet-point text to a tap-to-edit `TextInput` + 保存 button (matching `MemoTab.swift`'s pattern) plus a photo grid using `expo-image-picker`'s `launchImageLibraryAsync` with add/delete.
- Verification: `npm run typecheck` passed after each step. `pod install` succeeded (source globbing already picks up new Swift files automatically via the local podspec's `**/*.swift` pattern). `xcodebuild ... build` for the `Memora RN Test` simulator passed with `BUILD SUCCEEDED` twice (once after the Swift bridge additions, once after the RN UI wiring). Live-verified via the simulator screenshot+tap loop: (1) opened a `native-sample` file's Transcript tab, saw the PlayerBar render, tapped play, confirmed the icon toggled to pause and position advanced 0:00→0:01 (JS-fallback path, since the sample has no real file — expected and correct). (2) Recorded a real ~2m49s clip via the existing Home FAB recording bridge (had to grant the iOS microphone permission dialog first), opened its Transcript tab, and confirmed the PlayerBar showed `00:00 / 02:49` — the **real** recorded duration, not the fallback's fixed 12s — which is concrete proof the native `AVAudioPlayer` path is live and reading the actual file, not simulated. A tap that landed on the seek track (not the play circle) correctly jumped position to ~49% of duration (01:24), incidentally confirming the tap-to-seek math is also correct.
- Known gap, not fully verified this session: after the real-file playback check, the physical Simulator app window entered a broken macOS focus/accessibility state (`System Events` could no longer enumerate its windows — `count of windows` returned 0 even after quitting, force-killing, and relaunching Simulator.app multiple times, and even `frontmost` queries against all processes started failing). This blocked further automated tap testing. The user was asked and chose to skip visual verification of the Memo tab (text edit + photo attachment) for this session rather than keep fighting the environment. The Memo tab code compiles and follows the same verified pattern as the working Transcript tab, but has **not** been screenshot-confirmed — say so plainly if asked, do not claim it works from code-reading alone.
- **Correction to an earlier claim in this same log**: an initial final-validation pass mistakenly reported `RN workspace build-for-testing ... passed with TEST BUILD SUCCEEDED` before the actual background command had finished — the real result (checked properly afterward) was `** TEST BUILD FAILED **`, isolated to the `MemoraRNTests` target with `cannot load underlying module for 'EXConstants'` in the pre-existing `MemoraRNTests/MemoraSharedStoreBridgeAdapterTests.swift` (a file untouched this session). This reproduced consistently across three attempts: plain retry, `ModuleCache.noindex` wipe, and a full `DerivedData` wipe (the last one appeared to hang indefinitely at ~0% CPU after ~6 minutes and was killed rather than waited out further). The regular app build (`xcodebuild ... build`, no `-for-testing`) succeeded reliably throughout this entire session, including after every dependency change, and is what was used for every actual device/simulator verification (recording, real playback, etc.) — only the separate **test target's** build is affected.
- Most likely cause, not fully confirmed: this session ran `pod install` after adding `expo-image-picker` and the new native Swift files, which regenerates the Pods project and Expo XCFramework switch scripts; `EXConstants` specifically is not one of the precompiled Expo frameworks (pod install's own output only lists `ExpoFileSystem`, `ExpoFont`, `ExpoModulesCore`, `ExpoModulesWorklets` as precompiled) — it's built from source via a script phase each time, and several of these script phases are explicitly logged as running "during every build" because their output dependencies aren't declared, which can cause build-ordering races. This is a plausible but unverified hypothesis; the actual root cause needs a focused debugging session, ideally opening the project directly in Xcode.app to see the full diagnostic (not just tail-truncated `xcodebuild` CLI output) and to check `MemoraRNTests`' target dependencies/build phases against `EXConstants`.
- Final validation pass, corrected: `npm run typecheck` passed; `Packages/MemoraSharedData` `swift test` passed with 6 tests; **RN workspace `build-for-testing` currently fails** (see above — this needs to be fixed in a future session, it is a real regression in test-target build health, not acceptable to ignore); `git diff --check` clean (new files remain in the untracked `apps/mobile-expo` directory by design, confirmed via `git status --short`).
- Next: (a) **fix the `build-for-testing` / EXConstants regression** — open in Xcode.app directly for full diagnostics, check `MemoraRNTests` target dependency ordering against the `EXConstants` Pods target, consider whether `expo-image-picker` needs different integration; (b) restart the Mac or otherwise recover the Simulator window's accessibility state, then visually confirm the Memo tab (tap-to-edit text save/reload, photo add via the image picker, photo delete); (c) consider whether transcript segments should get a real STT-backed implementation eventually (currently correctly out of scope — protected files); (d) the Settings IA and Home fully-final polish items from earlier in this session remain the only other open threads.

### 2026-07-11 V6 app-shell gap execution

- やること: 添付された Claude の差分監査を引き継ぎ、P1 のアプリ骨格（浮遊タブバー、全タブ共通 FAB、タスクタブ）と即時のタイトル・トークン差分を実装する。変更したファイル: `apps/mobile-expo/app/(tabs)/_layout.tsx`、新規 `tasks.tsx`、新規 `V6FloatingTabBar.tsx` / `TasksScreen.tsx`、`HomeScreen.tsx`、`Screen.tsx`、`tokens.ts`。変更しないファイル: SwiftUI、STT コア、既存 iOS アプリ側の未コミット変更。
- Changed: 標準のラベル付き3タブを、V6 実測の4アイコン・60pt黒カプセル・左右16pt・Safe Area 上の dock に置換。Home 専用だった赤 FAB を廃止し、録音開始／インポート／会議キャプチャーの3項目を持つ全タブ共通の黒 FAB に移した。録音・インポートは既存 `MemoraNative` 契約を呼び、会議キャプチャーは未接続であることを明示する。タスクは V6 の期限切れ／今日／今後／完了折りたたみ／由来ファイル導線／追加シートをモックデータで追加した。
- Changed: `Screen` の既定タイトルを V6 の30ptに修正し、Home のみ32ptを明示指定。`quiet`、`neutralBorder`、`soft`、`paleLine` と V6 の角丸トークンを追加した。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` passed。`cd ios && pod install` passed。RN app target の `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' -quiet build` passed。初回シミュレータ画面で dock 自体は描画できたが、追加した `expo-blur` はこの Dev Client で `ViewManagerAdapter_ExpoBlur_ExpoBlurView` runtime error となったため、依存と Pod を削除し、V6 の暗い面・0.68 tint・白0.14 stroke・shadow による表現へ切替済み。依存削除後、手動リロードで Dev Client が SpringBoard へ戻り、最終画面の再キャプチャは未完了。
- Decisions: 実際に動かない native View を残さず、現行 Expo Dev Client で動く RN プリミティブだけで V6 の見た目を再現する。タスクは native persistence が未設計のため、この段階ではモック状態に留める。
- Next: 再ビルド済み Dev Client のタブ選択、FAB 展開、タスク追加／完了切替をスクリーンショットで確認する。その後は監査順に録音フルスクリーン、生成進捗、Paywall／オンボーディング、最後に Dynamic Island を実装する。

### 2026-07-11 Recording flow and immediate V6 corrections

- やること: P1 の未実装だった録音フルスクリーンと生成進捗を RN で実装し、停止後に既存 bridge の文字起こし／要約処理を呼ぶ。あわせて監査の即修正項目（File Detail の日本語タブ、Ask のスコープ順・初期値・固定入力バー）を反映する。変更したファイル: `apps/mobile-expo/src/features/capture/CaptureFlowProvider.tsx`、`V6FloatingTabBar.tsx`、`HomeScreen.tsx`、`AskAIScreen.tsx`、`FileDetailScreen.tsx`、root layout、ローカル Expo module の録音 API 定義と Swift handler。変更しないファイル: protected STT core、SwiftUI app、既存 SwiftData モデル。
- Changed: `MemoraRecordingImportHandling` に `pauseRecording` / `resumeRecording` / `discardRecording` を追加し、AVAudioRecorder の実操作として実装。RN は root-level capture provider を介して、録音開始・最小化・一時停止・再開・ハイライト・破棄確認・保存を一貫して保持する。停止後は文字起こし開始と要約生成の bridge を呼び、V6 数値に合わせた生成進捗画面を表示する。
- Changed: Ask を「全体 → プロジェクト → ファイル」、初期値「全体」、タイトル「Ask」、固定 composer へ変更。File Detail の `Summary/Transcript/Memo` を「要約/文字起こし/メモ」へ変更。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` passed。RN app target の `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' -quiet build` passed（既存の AVURLAsset deprecated warning のみ）。Computer Use で `Memora RN Test` simulator を直接操作し、浮遊 dock/FAB 展開、録音フルスクリーン、ネイティブ pause/resume、保存後の生成完了、タスク完了切替、Ask のスコープ順・全体初期選択・固定 composer を確認した。
- Decision: 生成画面は UI だけの偽進捗にせず、既存 `startTranscription` / `generateSummary` bridge 呼び出しを起動する。ただし、SwiftData host adapter が未接続のため、最終的な本アプリ永続化は別 W4 作業として残る。
- Next: Dynamic Island と完了スナックバーを追加し、その後 Home のファイル行・フィルターシート、File Detail の要約情報設計と操作シートを V6 に寄せる。RN test target の `EXConstants` 回帰も別途修正する。

### 2026-07-11 Dynamic Island and reliable capture transition

- やること: 録音の最小化、生成のバックグラウンド継続、完了通知を V6 の Dynamic Island 状態として追加する。変更ファイル: `CaptureFlowProvider.tsx` とこの移行ログ。変更しないファイル: native STT core、SwiftUI、SwiftData。
- Changed: active recording では 156×36 のライブ録音ピル、background generation では 198×36 の進捗ピル、完了時には 304×54 のスナックバーを表示する。物理 iPhone では実際の Dynamic Island が既に存在するため、V6 のモック用 idle pill は表示しない（シミュレータで二重表示になることを実測して修正）。
- Changed: 録音モーダルと生成モーダルを別々に切り替えると iOS React Native で画面遷移が競合したため、1つの full-screen Modal の内部で録音・生成コンテンツを切り替える構造へ変更した。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` passed。RN app-target build passed。Computer Use で simulator を操作し、録音画面 → 最小化ライブピル → ピルから録音復帰、録音停止 → `音声を解析中…` generation screen の直接遷移、完了状態を確認した。
- Next: Home のファイル行／フィルターシート、File Detail の要約情報設計／固定質問バー／操作シートを V6 に寄せる。別レーンで `MemoraRNTests` の EXConstants 回帰を修正する。

### 2026-07-11 Home rows and bottom sheets

- やること: V6 `V6AppShellView.swift` の `V6FileRow`、`V6HomeFilterSheet`、`V6FileMoreSheet` を RN Home に移す。変更ファイル: `HomeScreen.tsx`、新規 `V6AudioFileRow.tsx`、`Screen.tsx`、この移行ログ。変更しないファイル: STT core、SwiftUI、SwiftData、既存 native bridge。
- Changed: Home タイトルを `全ファイル` などの選択中フィルター + chevron にし、タップで V6 と同じ `全ファイル / プロジェクト / ライフログ` bottom sheet を開くようにした。ファイル一覧は `今日 / 今週 / 以前` に実データの recordedAt を基に区分し、アイコンタイル付きカードを廃止して、15pt タイトル、12ptメタ、2行要約、薄いセパレーター、処理中バー/失敗再試行/ellipsis のフラット行へ変更した。ellipsis は `タイトルを変更 / プロジェクトに移動 / 削除` の V6 action sheet を開く。
- Decision: rename は既存 File Detail の実装へ誘導し、プロジェクト移動と処理再試行はまだ bridge 契約がないため「準備中」を明示する。削除だけは既存 native-file delete を呼ぶ。機能がない操作を成功したようには見せない。
- Verification: `npm run typecheck`、`npx expo export --platform web`、`xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' -quiet build` がすべて passed。Simulator の Computer Use で Home の `今週` フラット行、フィルターシート、file action sheet の3状態を実画面で確認した。
- Next: File Detail の要約情報設計・固定質問バー・操作シートを V6 と比較して実装する。`MemoraRNTests` の `EXConstants` 回帰は別 QA レーンで追う。

### 2026-07-11 File Detail header and action shell

- やること: V6 `V6FileDetailView` の「アイコン列 → 1行タイトル/日付 → タブ → 本文 → 固定 Ask bar」構造に RN detail を合わせる。変更ファイル: `FileDetailScreen.tsx`、`Screen.tsx`、この移行ログ。変更しないファイル: playback/memo/transcription の bridge 契約、STT core、SwiftUI。
- Changed: back/share/more を上段にまとめ、ファイル名は V6 と同じ24pt相当の title slot に移動し、`numberOfLines={1}` で長い native filename を切り詰めた。本文冒頭に重複していたタイトル、ステータス、要約アクション群を外し、タブの要約本文から開始するよう整理した。Ask bar は scroll view 内ではなく Screen の `footerAccessory` として dock の上に固定した。
- Changed: more を Alert から V6 と同じ `タイトルを変更 / プロジェクトに移動 / 削除` bottom sheet へ置換。title rename は既存 native rename を呼ぶ入力モーダルにつないだ。project move/delete の detail 実装は bridge/確認設計を増やさず、現状の可否を明示する。
- Verification: `npm run typecheck`、`npx expo export --platform web`、`xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' -quiet build` が passed。Simulator で File Detail を開き、header order と dock 上に固定された Ask bar をスクリーンショットで確認した。
- Next: P1 の未実装 route（オンボーディング / ログイン / Paywall）の導線を実装し、全状態を V6 比較表で再点検する。

### 2026-07-11 Auth onboarding, login, and Paywall review route

- やること: V6 HTML の起動導線（オンボーディング3枚 → ログイン → メールコード → Paywall）を RN の個別 `/auth` route に実装する。変更ファイル: 新規 `app/auth.tsx`、新規 `AuthFlowScreen.tsx`、root route 登録、Preview Index、移行ログ。変更しないファイル: 実認証、StoreKit、課金サーバー、STT/SwiftUI/native bridge。
- Changed: V6 の record/summary/ask 3枚、スキップ、Apple/Google/メール選択、メール入力、6桁コード、Proの機能4項目、年額/月額選択、7日無料 CTA を実装した。`/preview` から常に起動できるため、既存 Home のレビューをログイン状態により遮断しない。
- Decision: Apple/Google 認証、メール送信、コード検証、購入復元、StoreKit 購入はバックエンド／決済の責務を決めずに模擬成功へ接続しない。外部 provider は「準備中」Alert、試用 CTA は明示した Free 続行 Alert、`あとで` は Home への遷移とした。
- Verification: `npm run typecheck`、`npx expo export --platform web`、`xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'generic/platform=iOS Simulator' -quiet build` が passed。Simulator Computer Use で `/auth` の初回オンボーディング、スキップ後のログイン選択、メール入力と送信無効状態をスクリーンショット確認した。
- Next: P1 UI shell は実装済み。残る実機能は認証/課金契約の決定後に別 workstream として接続する。並行して V6 差分表を再監査し、P2（タブ、文言、状態差分）を優先順に消化する。

### 2026-07-11 Ask AI P2 visual completion

- やること: Ask の残る V6 内部差分（新しい会話、scope caption、空状態サジェスト、添付 affordance、回答アクション、3点ローディング）を RN の既存 query facade を維持したまま実装する。変更ファイル: `AskAIScreen.tsx`、移行ログ。変更しないファイル: `MemoraNative.queryKnowledge` 契約、STT、SwiftUI、認証/課金。
- Changed: 右上に `＋ 新しい会話` を加え、現在のスコープの会話だけをリセットできるようにした。V6 の `全体 / プロジェクト / ファイル` 下の説明、3つのサジェスト質問、ペーパークリップ、右矢印送信、アシスタント回答下のコピー/タスク化/時刻、3点ローディングを追加した。
- Decision: copy、task化、添付は各々の永続化／検索契約が未接続のため、押下しても成功を装わず「準備中」Alert にする。サジェスト質問は既存 `queryKnowledge` を実際に呼ぶ。
- Verification: `npm run typecheck` と `npx expo export --platform web` が passed。Simulator を `/ask-ai` に直接遷移させ、全体スコープ初期選択、caption、サジェスト3項目、添付 affordance、dock 上の固定 composer をスクリーンショット確認した。
- Next: P2 の大きい残りは File Detail の Summary/Transcript/Memo の情報設計と、Home のプロジェクト/ライフログ実データである。どちらも単なるスタイルではなく data/bridge の境界が絡むため、仕様と現行契約を確認してから別スコープで進める。

### 2026-07-11 Ask in-app pill: invisible-pill bug resolved by cache/Simulator reboot, not code

- やること: 前回セッションで進行中とされていた `/tmp/memora-ask-pill-fresh` の Dev Client ビルドを検証し、Ask pill (`CaptureFlowProvider.tsx` の `AskIslandPill`) が実際に表示・タップ動作するか確認する。変更ファイル: なし（最終的に）。変更しないファイル: STT コア一式、`CaptureFlowProvider.tsx` 本体ロジック。
- Changed: 最終的にソースコードの変更はなし。調査中に `babel.config.js` を新規作成し `babel-preset-expo@57.0.2` を追加したが、`ExpoModulesWorklets` のネイティブクラッシュ（`EXC_BREAKPOINT`/`SIGTRAP`）を誘発したため、同じセッション内で完全に revert 済み（`babel.config.js` 削除、パッケージ uninstall）。
- Decision: Ask pill が白背景でほぼ見えない状態だったのは、Reanimated/Worklets のバージョン不整合警告オーバーレイと合わせて、古い Metro バンドラーキャッシュ・古い Simulator セッション状態が原因だった。Metro `--clear` 起動と Simulator の完全リブート（`CoreSimulatorService` 再起動＋ユーザーによる手動リブート）後、コード変更なしで正しく（黒背景・白文字・sparkles アイコン）描画された。babel 設定不足を恒久的な修正として追加するのは早計だった — 現状で正しく動いているため、追加の babel 設定は不要と判断し導入しなかった。
- Verification: Python(PIL) でスクリーンショットのピクセル値を直接サンプリングし、修正前は該当領域が純白 `(255,255,255)`、リブート後は `colors.ink` 相当の暗いピクセル `(13,13,13)` に変化したことを確認。`npm run typecheck` は変更前後とも passed。タップ後に Ask タブへ遷移するかは、ホスト側 `cliclick`/`osascript` の座標較正が確立できず自動検証できなかった（この点は未確認のまま）。
- Next: 実機またはインタラクティブな Simulator セッションで、Ask pill を手動タップして Ask タブへの遷移を確認すること。同種の「見えない/固まったアニメーション」問題が再発した場合は、まず Metro キャッシュと Simulator の状態をリセットしてから babel/Reanimated バージョンの疑いを検討すること。

### 2026-07-11 Tap-automation calibration fix + Memo/photo bridge partial verification

- やること: 前回未確認だった File Detail の Memo タブ（写真添付/削除）を実際にタップして目視確認する。変更ファイル: なし（検証のみ）。変更しないファイル: `CaptureFlowProvider.tsx`、Memo/photo ブリッジ実装一式、STT コア。
- Changed: ソースコードの変更はなし。ホスト側 `cliclick`/`osascript` によるタップ自動化の座標較正がこれまで不正確だった原因を特定し、修正した。`osascript`で`System Events`の`group 1 of window 1`（Simulatorのデバイス画面コンテンツ自体を表すUI要素）の`position`/`size`を取得し、`screen = groupPosition + (devicePixel / screenshotSize) * groupSize` という変換式で正確に較正できることを確認した（以前使っていた `windowPosition + 固定オフセット` 方式は不正確だった）。
- Decision: この較正式を使い、Home のファイル行タップ → File Detail 遷移 → メモタブ切り替え → 「写真を添付」タップまでは確認できた。ネイティブの `PHPickerViewController`（写真ピッカー）のサムネイルグリッド内の個別タップだけは、この較正式でも選択状態の変化を確認できなかった（ピッカーの開閉自体は正しく動作し、Xボタンでのキャンセルは同じ較正式で正確に効いた）。ピッカーグリッド内サムネイルの正確な座標だけ何らかのズレが残っている可能性があり、原因は特定できなかった。
- Verification: スクリーンショットで、ファイル行タップ→File Detail開く→メモタブへの切り替え→「タップしてメモを追加」入力欄と「写真を添付」ボタン→タップ後にネイティブ写真ピッカー（`expo-image-picker`ブリッジ）が実際に開く→Xボタンでキャンセルして戻る、の一連の流れを視覚確認した。写真の実際の選択・添付・削除の完了までは確認できなかった。
- Next: 写真ピッカーのサムネイル選択だけ、実機か手動のインタラクティブ Simulator セッションで確認すること。较正式自体は他の画面遷移確認にも再利用できる（`group 1 of window 1` の position/size を使う変換式）。

### 2026-07-11 Golden-ratio spacing/radius/typography tokens + dev font preview screen

- やること: CLAUDE.md §6.3 の黄金比トークン(spacing 5/8/13/21/34/55、radius 8/13/21、typography 12/14/17/21/26/34)を導入し、日本語フォント候補をプルダウン的に比較できる開発者向け機能を追加する。変更ファイル: `src/design/tokens.ts`、`src/features/dev/devFontCandidates.ts`（新規）、`src/screens/DevFontPreviewScreen.tsx`（新規）、`app/dev-fonts.tsx`（新規）、`app/_layout.tsx`、`src/screens/SettingsScreen.tsx`、`package.json`。変更しないファイル: STTコア一式、`MemoraNative`ブリッジ、`CoreDTOs.swift`。
- Changed:
  - `tokens.ts` の `spacing`/`radius` の値を黄金比スケールに更新（キー名は既存のまま据え置き、72+54箇所の既存利用が自動追従）。`typography`トークン（`size` + `lineHeight()`ヘルパー）を新規追加。
  - `@expo-google-fonts/{noto-sans-jp,zen-kaku-gothic-new,m-plus-1p,ibm-plex-sans-jp,murecho}` と `expo-font` を追加（`npx expo install`）。app.json に `expo-font` config plugin が自動登録された。
  - フォント切替は当初「アプリ全体の `Text`/`TextInput` の `defaultProps.style` をグローバルパッチする」方式で実装しようとしたが、現行 React Native（0.86, Flowの`component`構文）の `Text` は関数コンポーネントで `defaultProps` にもクラスの `.render` メソッドにも対応しないため、**この方式は動作しないと判明し実装前に破棄した**。代わりに、`/dev-fonts`という専用プレビュー画面（モーダル route）を追加し、その画面内でのみ候補フォントの `fontFamily` を明示的にスタイル指定してサンプルテキスト（見出し/本文/キャプション、日本語+英数字混在）を切り替え表示する方式にした。Settings の「開発者向け」セクションに「フォント候補を試す」行を追加し、そこから遷移する。
  - フォント選択状態は永続化していない（`AsyncStorage`等が未導入のため、今回はネイティブ再ビルドを避ける判断でメモリ内 state のみ）。
- Verification: `npm run typecheck` は本セッション中の各変更後すべて passed。Simulator で spacing/radius 変更後の Home/Settings 画面を目視確認（レイアウト崩れなし）。`/dev-fonts` へは `xcrun simctl openurl` の expo-router deep link (`memora-rn:///dev-fonts`) で到達を確認（Settings 内スクロール操作の自動化が本セッションでは安定せず、UIタップ経由のルートは未検証）。Noto Sans JP チップ選択後、プレビュー本文の字形・太さがシステム標準と明確に異なることをスクリーンショット比較で確認し、フォント切替が実際に機能していることを確認した。
- Next: フォント選択の永続化（`AsyncStorage`導入、ネイティブ再ビルド1回で済む想定）。Settings画面からのタップ遷移（スクロール込み）の実機/手動確認。spacingトークンの黄金比化に伴い、画面ごとに残っているハードコードされた生の余白値（`padding`/`margin`/`gap`の直書き数値、多数残存）を1画面1コミットで監査していく作業は未着手。

### 2026-07-11 Screen-by-screen spacing audit (Home / File Detail / Ask AI / Settings / Tasks)

- やること: 黄金比 spacing トークン導入後に残っていた、各画面のハードコードされた生の `padding`/`margin`/`gap` 数値を、最も近いトークン値（xs=5, sm=8, md=13, lg=21, xl=34）に置き換える。変更ファイル: `HomeScreen.tsx`、`FileDetailScreen.tsx`、`AskAIScreen.tsx`、`SettingsScreen.tsx`、`TasksScreen.tsx`。変更しないファイル: STTコア一式、`MemoraNative`ブリッジ。
- Changed: 各画面の生数値を、行番号ベースの置換スクリプトで元の値に最も近いトークンへ機械的に置換した（例: `gap: 24`→`spacing.lg`、`paddingVertical: 13`→`spacing.md`など）。以下は意図的に据え置いた: (1) 2px以下の極小値（`marginTop: 2`など、意図的な密着表現）、(2) 中間値で近似先が曖昧なもの（`gap: 3`など）、(3) タブバー回避用の機能的なオフセット（`paddingBottom: 94`など、装飾目的の余白ではない）。
- Verification: `npm run typecheck` と `npx expo export --platform web` はいずれの画面変更後も passed。5画面すべて（Home、File Detail、Ask AI、Settings、Tasks）を expo-router の deep link（`memora-rn:///...`）で直接開き、スクリーンショットでレイアウト崩れがないことを目視確認した。
- Next: 今回はグローバル装飾トークンの範囲に絞った。`radius`（角丸）の生値監査は未着手（例: `borderTopLeftRadius: 16`など）。`Preview`ルートや細部のモーダル/シートの隅々までは全状態を確認していない。

### 2026-07-11 iOS 26 Liquid Glass (@callstack/liquid-glass) for tab bar, FAB, and bottom sheets

- やること: ユーザー指定の `@callstack/liquid-glass`（https://github.com/callstack/liquid-glass）を導入し、下部floating dock、FAB、各種ボトムシートに本物のiOS 26 Liquid Glassマテリアルを適用する。変更ファイル: `package.json`、`ios/Podfile.lock`（pod install）、`V6FloatingTabBar.tsx`、`HomeScreen.tsx`、`FileDetailScreen.tsx`、`TasksScreen.tsx`。変更しないファイル: STTコア一式、`MemoraNative`ブリッジ。
- Changed: ライブラリの要件（React Native 0.80+、Xcode 26+）を確認 — 本プロジェクトは RN 0.86 / Xcode 26.5 で要件を満たす。`npx expo install @callstack/liquid-glass` でインストール後、`pod install`（`LANG=en_US.UTF-8`/`LC_ALL=en_US.UTF-8` が必要だった、デフォルトのターミナルロケールだと CocoaPods が `Encoding::CompatibilityError` で落ちる）。
  - `V6FloatingTabBar.tsx`: dock ピルと FAB を覆っていた自作の半透明オーバーレイ（`glassTint` の `rgba` View 重ね）を撤去し、`LiquidGlassContainerView`（`spacing=10` で dock と FAB のガラスが近接時に融合するように）+ `LiquidGlassView`（`effect="regular"`、`colorScheme="dark"`、FAB 側は `interactive`）に置き換えた。
  - `HomeScreen.tsx` / `FileDetailScreen.tsx` / `TasksScreen.tsx`: フィルターシート、ファイル操作シート、削除確認、タイトル変更、タスク追加シートの背景 `View` を `LiquidGlassView`（`effect="regular"`、`colorScheme="light"`）に置き換えた。エクスポート用のフルスクリーンモーダル（`exportSheet`）は対象外とした（Appleのデザイン言語でも全画面コンテンツ背景まではガラス化しないため）。
  - すべてのガラス箇所に `isLiquidGlassSupported` によるフォールバックスタイル（iOS 26未満では従来の不透明背景色に戻る）を用意した。
- Verification: `xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'id=458A23AB-B4A3-43BF-8F40-4D6F56903088' build` が `BUILD SUCCEEDED`。Simulator（iOS 26.5）にインストールし、アプリはクラッシュせず起動、プロセスが生存し続けることを確認した。スクリーンショットで、dock/FABが以前の不透明な `#101012` から実際に半透明・周囲の色を拾うグレー調へ変化していることを確認（本物のガラスマテリアルが乗っている証拠）。Home のフィルターシートも同様に半透明の白ガラス調で開くことを確認した。`npm run typecheck` と `npx expo export --platform web` は最終的に passed。
- Not verified: File Detail の「…」その他アクションシート、タイトル変更/削除確認ダイアログ、Tasks の追加シートは、画面右上に固定表示される Expo Dev Client の浮遊ツールボタンとタップ位置が重なってしまい、このセッションでは自動タップ検証ができなかった（コードパスは Home のシートと同一パターンのため機能するはずだが、目視未確認）。
- Next: 上記の未検証シートを手動またはツールボタンの干渉がない実機で確認すること。エクスポートのフルスクリーンモーダルへガラスを適用するかは、Apple のデザイン言語に照らして判断が必要（今回は意図的に対象外とした）。

### 2026-07-11 Liquid Glass color correction (white / max transparency) + expo-image + flash-list install

- やること: 直前の Liquid Glass 導入が黒っぽい見た目になっていたため、ユーザー指示で白・透過度最大に修正する。加えてリッチ化バッチの第一弾として `expo-image`・`@shopify/flash-list` を導入する。変更ファイル: `V6FloatingTabBar.tsx`、`HomeScreen.tsx`、`FileDetailScreen.tsx`、`TasksScreen.tsx`（`effect="clear"` へ統一）、`package.json`、`ios/Podfile.lock`。変更しないファイル: STTコア一式、`MemoraNative`ブリッジ。
- Changed:
  - `V6FloatingTabBar.tsx`: dock/FAB の `LiquidGlassView` を `colorScheme="dark"` → `colorScheme="light"`、`effect="regular"` → `effect="clear"`、`tintColor` を `rgba(16,16,18,0.55)`（濃い黒）→ `rgba(255,255,255,0.12)`（薄い白、透過度最大）に変更。アイコン色も白 → ダーク（`#0D0D0D`系）に反転し、フォーカス時のハイライト背景・ボーダー・iOS<26フォールバック背景色もすべて白系トーンに統一した。
  - Home/FileDetail/Tasks の全ボトムシート（フィルター、ファイル操作、削除確認、タイトル変更、タスク追加）も `effect="regular"` → `effect="clear"` に統一し、同じ透過度最大の白ガラスに揃えた。
  - `expo-image`・`@shopify/flash-list` を `npx expo install` で追加し、`pod install` を実行（`LANG=en_US.UTF-8`/`LC_ALL=en_US.UTF-8` 要）。`FileDetailScreen.tsx` のメモ写真表示を `react-native` の `Image` から `expo-image` の `Image`（`transition={150}`）に置き換えた。
- Decision: `@shopify/flash-list`（v2.0.2、`estimatedItemSize` 不要な新API）は導入したが、Home の一覧描画には**まだ配線していない**。理由: 現在の `Screen` コンポーネントは `children` をまるごと1つの `ScrollView` に入れる設計で、`FlashList` はネストされた `ScrollView` の中で正しく仮想化できない（RN の既知の制約）。正しく組み込むには `Screen` にヘッダー分離＋リストモードを追加する設計変更が必要で、かつ現在のモックデータ件数（数件）では仮想化の実利がほぼゼロなため、今回は見送った。ライブラリは import 済みだが未使用の状態で保持している。
- Verification: `pod install` 成功、`xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -destination 'id=458A23AB-B4A3-43BF-8F40-4D6F56903088' build` が `BUILD SUCCEEDED`。Simulator にインストールしてクラッシュなく起動、プロセス生存を確認。スクリーンショットで dock/FAB が背景にほぼ溶け込むレベルまで透明化し、アイコンが濃色でくっきり視認できることを確認。Home のフィルターシートも同じ白・透過度最大の設定で開くことを確認した。`npm run typecheck` と `npx expo export --platform web` は最終的に passed。
- Next: `@shopify/flash-list` を実際に使うなら、まず `Screen` コンポーネントの `ListHeaderComponent` 対応（リストモード追加）を別作業として設計すること。`@gorhom/bottom-sheet`・`sonner-native`・`react-native-keyboard-controller` は未着手のまま（`react-native-gesture-handler` の追加導入とネイティブ再ビルドが必要）。

### 2026-07-11 Floating tab bar overlay fix + radius token pass

- やること: ユーザーから「メニューバーの後ろが白くて透過を確認できない」と報告を受け、原因調査と修正。ついでに角丸(`radius`)の生値監査も進める。変更ファイル: `app/(tabs)/_layout.tsx`、`HomeScreen.tsx`、`FileDetailScreen.tsx`。変更しないファイル: STTコア一式、`MemoraNative`ブリッジ。
- Root cause: カスタム `tabBar` を渡していても、React Navigation の bottom-tabs はデフォルトでは画面コンテンツの高さを「タブバー分を引いた高さ」にレイアウトする（コンテンツはタブバーの下を実際には通らない）。V6の丸みを帯びた見た目のせいで浮いているように見えていただけで、構造的には固定の帯だった。加えて、Memora の画面はほぼ全て白背景のため、白ガラスを白背景に重ねると（Apple純正の白基調画面と同様）視覚的な差がほぼ出ない、という二重の理由があった。
- Changed: `app/(tabs)/_layout.tsx` の `screenOptions` に `tabBarStyle: { position: 'absolute', backgroundColor: 'transparent', borderTopWidth: 0, elevation: 0 }` を追加。これによりコンテンツが画面全体（タブバーの裏側も含む）まで広がり、真の浮遊オーバーレイになる。ネイティブ変更ではないため再ビルド不要（JS/設定のみ）。
- Verification: `npm run typecheck` passed。Simulator へインストール後の目視確認は実施したが、モックデータの件数が少なく（Home 1件、Settings は下部セクションがビューポート内に収まりきる程度）、タブバーの裏を実際にスクロールしてコンテンツが通過する場面を明確に再現できなかった。座標較正済みのタップ操作は機能したが、本セッションで確立したスクロールジェスチャ自動化（`cliclick` drag、CGEvent スクロールホイール）はこの取り組みでは安定して発火しなかった。
- Not verified: 実際に色や画像を含むコンテンツがタブバーの裏を通過する様子。白背景オンリーの画面では、ガラスが機能していても視覚的な違いがほぼ出ないのは仕様どおりの見え方であり、真に確認するには写真グリッドやプロジェクトの色付きアバターなど、コントラストのあるコンテンツをタブバー付近までスクロールする必要がある。
- 追加: `radius`（角丸）の生値監査を実施。チェックボックス・ドット・ピルボタン・アイコン背景などのほとんどは意図的な円形/カプセル形状（`borderRadius = 高さ/2`）であり、変更不要と判断した。唯一トークン化したのは Home/FileDetail のボトムシート上部角丸（`16` → `radius.cardAlt`(21)、iOSネイティブのシート角丸慣習に近づけるための意図的な選択で、単純な最近傍距離ではなくデザイン意図を優先した）。
- Next: タブバーの透過を明確に確認したい場合は、写真グリッドやプロジェクトの色付きアバターがタブバー付近まで来る画面で確認すること。または `V6FloatingTabBar` の tint を一時的に濃い色に戻して構造的な重なりだけを検証する、という切り分けも可能。

### 2026-07-12 スクロールエッジ・フェード + Liquid Glass 透過さらに強化

- やること: ユーザー指摘「設定画面でスクロールするとメニューバーの上で見切れる」「もっと透過させて」に対応。計画 `~/.claude/plans/liquidglass-quiet-ritchie.md` に基づく。変更ファイル: `package.json`/`ios/Podfile.lock`（expo-linear-gradient）、`V6FloatingTabBar.tsx`、`HomeScreen.tsx`/`FileDetailScreen.tsx`/`TasksScreen.tsx`。変更しないファイル: STTコア一式、`MemoraNative`ブリッジ。
- 原因（見切れ）: 直前に `app/(tabs)/_layout.tsx` の `tabBarStyle` を `position:'absolute'` 化した結果コンテンツがタブバーの裏へ回り込むようになったが、ガラスが `effect="clear"` + 高透過のため裏を流れるテキストがくっきり見え、バーの縁で乱暴に切り取られて見えた。iOS 26 純正の scroll edge effect 相当がこのライブラリには無い（API は `effect`/`tintColor`/`colorScheme`/`interactive` のみ）。
- Changed:
  - `expo-linear-gradient@57.0.0` を `npx expo install` → `pod install`（`LANG/LC_ALL=en_US.UTF-8` 必須）。`EXLinearGradient` pod 追加。
  - `V6FloatingTabBar.tsx`: dock/FAB の背面に `LinearGradient`（`pointerEvents="none"`、`colors=['transparent', colors.canvas]`、`locations=[0,0.55]`、`height = insets.bottom+60+40`、`left/right: -16` で container の左右パディングを相殺し画面幅いっぱい）を追加。コンテンツがバー手前で canvas 色に溶ける scroll edge fade を実現。
  - 透過強化: dock/FAB の `tintColor` を `rgba(255,255,255,0.12)` → `rgba(255,255,255,0.04)`、`glassPill`/`fab` の `borderColor` を `0.4` → `0.22`。
  - シート透過: 各シート（Home フィルター/操作、FileDetail more/delete/rename、Tasks add）の内部要素の不透明フィル（`sheetRow` の `backgroundColor: colors.faint`、Tasks `input` の `colors.soft`）を `rgba(255,255,255,0.5)` に変更。これで `effect="clear"` のガラスが実際に透けるようになった（従来は内部が不透明で板に見えていた）。
- Verification: `npm run typecheck` passed。`pod install` 成功、`xcodebuild ... -destination 'id=458A23AB-...' build` が `BUILD SUCCEEDED`。Simulator（iOS 26.5）へインストールしクラッシュなく起動・プロセス生存を確認。**見切れ検証**: Settings（長コンテンツ）で最下部行がタブバー手前の柔らかいグラデーション帯に溶け、乱暴な切り取りが解消されたことをスクリーンショット + 拡大で確認。**透過検証**: dock/FAB がほぼ透明なガラスになり、フィルターシートを開くと半透明の行の下にタブバーのアイコンが薄く透けて見える（ガラスが機能している証拠）ことを確認。文字・アイコンは可読。`npx expo export --platform web` passed。
- Note: 白背景オンリーの画面では fade 帯が canvas（白）に溶けるため依然として白っぽく見えるが、これは以前の「不透明な白ブロックがコンテンツを隠す」問題とは異なり、上端 transparent のグラデーションで滑らかに溶けるだけ（コンテンツは隠れない）。色付きコンテンツ（プロジェクトの色付きアバター等）がバー付近を通る場面での見え方は引き続き実機/手動確認推奨。
- Next: 残タスク棚卸しは計画ファイル `~/.claude/plans/liquidglass-quiet-ritchie.md` の「残タスク棚卸し」節（B: UIポリッシュ / C: リッチUIライブラリ / D: フォント永続化 / E: 実機能 / F: QA）を参照。

### 2026-07-12 グラデーション撤去 + ボトムシートをフローティングカード化（余白・スライドアップ・ハンドル）

- やること: ユーザー指摘に対応。(1) 画面下部の scroll edge グラデーションを撤去（背景は後で検討するとのこと）、(2) ボトムシートに余白を入れる、(3) シートを下から上へスライドアップ表示、(4) 他の磨き込み。変更ファイル: `V6FloatingTabBar.tsx`、`HomeScreen.tsx`、`FileDetailScreen.tsx`、`TasksScreen.tsx`。すべて JS のみ（ネイティブ再ビルド不要）。変更しないファイル: STTコア、`MemoraNative`ブリッジ。
- Changed:
  - `V6FloatingTabBar.tsx`: 直前に入れた `LinearGradient`（scroll edge fade）と `scrollEdgeFade` スタイル、`expo-linear-gradient`/`colors` の import を撤去。タブバー下部はグラデーション無しのクリーン状態に戻した。
  - ボトムシート 3 種（Home フィルター/操作、FileDetail more、Tasks 追加）を「余白付きフローティングカード」に統一: `borderTopLeftRadius/borderTopRightRadius` → `borderRadius: radius.lg`（全角丸）、`marginHorizontal: spacing.md` + `marginBottom: spacing.xl` を追加して画面端から浮かせた。
  - Home の 2 シートは `animationType="fade"` → `"slide"`（下から上へスライドアップ）。FileDetail more / Tasks add は既に `"slide"`。
  - 磨き込み: Home/FileDetail の各シート上部に iOS 標準のグラブハンドル（`sheetHandle`、`36×4` の丸角バー）を追加。Tasks は既存ハンドルの余白を他と統一。
- Verification: `npm run typecheck` passed、`npx expo export --platform web` passed。JS のみ変更のため既存 Dev Client のまま Metro `--clear` 再起動で反映。Simulator でクラッシュ無く起動・プロセス生存を確認。グラデーション撤去はタブバー上部の拡大スクリーンショットで確認。Home フィルターシートを開き、左右余白・全角丸・上部グラブハンドルのフローティングカードになっていることを確認。
- Note: `expo-linear-gradient` は import を外したが npm/pod には導入済みのまま（未使用依存）。害は無いが、完全に不要なら別途 uninstall + pod install で除去可能。シート下端は半透明ガラス越しに背後（dimmed なタブバー）がうっすら見えるが、Modal の scrim で暗転しているため許容範囲。より完全に浮かせたい場合は `marginBottom` をタブバー高さ相当（≈ `insets.bottom + 60`）まで上げる案がある（今回は iOS 標準のボトム余白 `spacing.xl` に留めた）。

### 2026-07-12 V6 デザイン突き合わせ（A）: 差分棚卸し + サマリー文字色の忠実度修正

- やること: 計画 A（V6 正との突き合わせ）。`Memora/Views/V6/V6DesignTokens.swift`・`V6AppShellView.swift`・`V6FileDetailView.swift` を正として RN 実装と比較し、ユーザー上書き分を除いた「真の忠実度バグ」を特定・修正。変更ファイル: `V6AudioFileRow.tsx`、`HomeScreen.tsx`。変更しないファイル: STTコア、`MemoraNative`ブリッジ。
- 突き合わせ結論:
  - **背景色は問題なし**: 当初 V6 の `canvas=#ECECEC` と RN の `#FFFFFF` の差を疑ったが、V6 アプリシェル本体（`V6AppShellView` L61）は `V6Color.white`（白）を使用。RN の白背景は V6 と一致。ガラスが見えにくいのは「白背景に白ガラス」というユーザー上書き（本来 V6 のタブバーは charcoal 68% のダークガラス）の当然の帰結であり、背景バグではない。
  - **ユーザー上書き分（V6 と異なるが正しい、触らない）**: (1) タブバー/FAB を白・高透過に変更（V6 正はダークガラス）、(2) ボトムシートを余白付き半透明カード＋スライドアップ＋ハンドルに変更（V6 正は端末幅いっぱいのネイティブ `.presentationDetents` シート＋faint 不透明行）。
  - **忠実度バグ（修正した）**: V6 のファイル行/ライフログの**サマリープレビュー文字色**は `V6Color.muted (#8E8EA0)` だが、RN は `colors.textMuted (#3A3A3C)` で暗すぎた。`V6AudioFileRow.summary` と `HomeScreen.highlightSummary` を `colors.textMutedLight (#8E8EA0)` に修正。
- Verification: `npm run typecheck` passed、`npx expo export --platform web` passed。Simulator の Home でサマリー文字がピクセル平均 `(146,146,164)` となり V6 muted 目標 `#8E8EA0 = (142,142,160)` とほぼ一致（差はアンチエイリアス）することを確認。
- 未修正で残した差分（判断保留）: (1) RN の radius トークンは黄金比（8/13/21、CLAUDE.md §6.3 準拠で既に導入済み）で、V6 正の `V6Radius`（chip6/field12/card14/cardAlt16/pill24）とは体系が異なる。全画面に影響する体系変更のため今回は据え置き。(2) ファイル行タイトルの weight は V6 が `.medium(500)`、RN が `600`。極めて微差で Codex の意図の可能性もあり据え置き。(3) File Detail のサマリーセクション本文色は別コンポーネントにあり未照合。
- Next: 上記の据え置き差分（radius 体系 / title weight / File Detail 本文色）を V6 に合わせるか、黄金比・現行を維持するかはデザイン方針の判断が必要。残りの大タスクは計画ファイル `~/.claude/plans/liquidglass-quiet-ritchie.md` を参照。

### 2026-07-12 V6 突き合わせ（A）続き: 保留差分の方針決定 + 反映

- やること: 前エントリで保留にした差分について、ユーザーに方針を確認して反映。変更ファイル: `V6AudioFileRow.tsx`。
- ユーザー判断:
  - **radius 体系**: 現状の黄金比（8/13/21、CLAUDE.md §6.3）を**維持**（V6 の 6/12/14/16/24 には合わせない）。→ tokens.ts は変更なし。
  - **ファイル行タイトルの weight**: V6 の `medium(500)` に**合わせる**。→ `V6AudioFileRow.title` の `fontWeight` を `600` → `500` に変更。
  - **File Detail サマリー本文色**: 前エントリで別ファイル `Memora/Views/FileDetail/SummaryTab.swift` を照合し、RN はすでに V6 一致（メタ=muted、決定事項=tertiary、次のアクション=ink）と確認済み。修正不要。
- Verification: `npm run typecheck` passed、`npx expo export --platform web` passed。Simulator の Home でファイルタイトルが medium 相当の太さで表示され、直前のサマリー薄色化と併せて V6 の見た目に一致することを拡大スクリーンショットで確認。File Detail 要約タブも回帰なし（表示崩れ無し・色 V6 一致）を確認。
- 結論: **計画 A（V6 突き合わせ）は完了**。RN 実装は、ユーザーが意図的に上書きした箇所（タブバー白・高透過、シートの余白付き半透明カード＋スライドアップ、radius 黄金比）を除き、V6 canonical に忠実。
- Next: 残タスクは計画ファイル `~/.claude/plans/liquidglass-quiet-ritchie.md` の B（リッチ UI ライブラリ, gesture-handler + 再ビルド前提）/ C（フォント永続化, AsyncStorage + 再ビルド）/ D（実機能, バックエンド決定待ち）/ E（QA, EXConstants 修復等）。いずれも「1回のネイティブ再ビルド」「バックエンド/所有権の決定」「Xcode.app での診断」のいずれかが前提。

### 2026-07-12 File Detail 要約タブの添付グリッド

- やること: ユーザー承認により、V6 の File Detail 要約タブにある「添付」グリッドを追加する。添付のデータ正本は新設せず、既存メモ写真を読み取り専用で再利用する。変更ファイル: `apps/mobile-expo/src/screens/FileDetailScreen.tsx`、移行ログ。変更しないファイル: `MemoraNative` のネイティブ実装、写真メモブリッジ、STT コア、SwiftUI、バックエンド。
- Changed: `memoNotes.photos` を3列の正方形サムネイルとして要約タブに表示。V6 と同じ「添付 / Ask AI が内容を読み取ります」見出し、端末内バッジ、破線の追加タイル、Pro ストレージ案内を追加した。追加タイルは保存契約を二重化せず既存のメモタブへ遷移するため、写真の追加／削除の所有者は従来どおりメモタブに一本化される。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（1.8MB bundle）。写真付きの実データを用いた Simulator 目視は未確認。
- Next: 写真を1件以上添付したファイルで、要約タブの3列グリッド・端末内バッジ・追加タイル遷移を実機または Simulator で確認する。テンプレート／モデルの引き渡しは次の Handoff Log に記す既存 `summary-options` 契約への接続として完了した。

### 2026-07-12 GENERATE 選択値の summary-options 接続

- やること: GENERATE のカスタムテンプレートと設定済み AI モデルを `generateSummary` へ渡す。変更ファイル: `apps/mobile-expo/src/features/capture/CaptureFlowProvider.tsx`、移行ログ。変更しないファイル: `MemoraNative` ネイティブ実装、STT コア、`AIService.swift`、`CoreDTOs.swift`、バックエンド、SwiftUI。
- Investigated: 依頼時の「要約オプション契約の拡張が前提」という記録を再監査したところ、既存の `SummaryOptionsDTO` はすでに `provider` と任意の `templateId` を持ち、Expo module の TS API、Swift `MemoraSummaryOptionsDTO`、bridge contract まで透過済みだった。従って契約を重複拡張せず、UI の未接続だけを直す。
- Changed: GENERATE のテンプレートを表示文字列ではなく安定 ID（`meeting-notes` / `key-points` / `action-items` / `clean-transcript`）で管理した。カスタム生成時のみ選択 `templateId` と設定から読み取った `provider` を `runGeneration` に渡し、そのまま `MemoraNative.generateSummary` へ渡す。自動生成・スキップは `templateId` を省略して provider のみを渡す。既存のファイル名永続化の挙動は変更していない。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（1.8MB bundle）。タップ自動化の画面端不安定性のため、実録音→カスタムテンプレート→生成完走の Simulator 目視は未確認。
- Next: 実サマライザの host adapter を接続する段階で、上記安定 ID をプロンプト／テンプレート解決へ対応付ける。現時点の sample generator は request を受けるだけで template による本文差分を作らない。

### 2026-07-12 リッチ・フローティングボトムシートの基盤導入

- やること: Expo SDK 57 / RN 0.86 と互換のライブラリを確認して、既存のフローティングカード型シートへパン／バックドロップ／下スワイプ閉じを導入する。変更ファイル: `package.json` / lockfile / `app/_layout.tsx` / 新規 `FloatingBottomSheet.tsx` / `FileDetailScreen.tsx` / 移行ログ。変更しないファイル: STT コア、要約／写真ブリッジ、バックエンド、SwiftUI。
- Investigated: Expo SDK 57 公式ドキュメントの推奨 `react-native-gesture-handler@~2.32.0` と `npx expo install` を使用した。`@gorhom/bottom-sheet` v5.2.14 は Reanimated 4 と Gesture Handler 2.16 以上を peer dependency として許容し、既存の Reanimated 4.5.0 と整合する。
- Changed: root を `GestureHandlerRootView` と `BottomSheetModalProvider` で包んだ。新しい `FloatingBottomSheet` は dynamic sizing、バックドロップ閉じ、下スワイプ閉じを提供し、背景カードのスタイルは既存 `LiquidGlassView` に残して白・高透過／黄金比 radius／下余白の既定判断を維持する。まず File Detail の「その他」と「書き出す」だけを移行し、Home／Tasks は動作確認後に別バッチとした。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB bundle）。`pod install` passed（`RNGestureHandler 2.32.0` を autolink）。Simulator 向け `xcodebuild ... clean build` は exit 0。新規 Dev Client を Simulator にインストールしたが、初回ランタイムログに `NativeLiquidGlassModule could not be found` が出て白画面となり、その後の起動は SpringBoard に戻った。従って iOS でのシート表示・ドラッグ・閉じ操作は**未確認**。
- Next: Bottom Sheet の見た目を評価する前に、Liquid Glass native module の registration と Dev Client 起動を復旧する。このランタイム問題を bottom-sheet の不具合と断定しない。復旧後、File Detail 2シートをまず検証し、合格後に Home／Tasks の共通化を判断する。

### 2026-07-12 Liquid Glass の native registration 復旧（進行中）

- やること: 新 Dev Client 起動時の `NativeLiquidGlassModule` 未登録を、autolinking/codegen/static-link の範囲で復旧する。変更ファイル: `apps/mobile-expo/ios/Podfile`、移行ログ。変更しないファイル: STT コア、`MemoraNative` ブリッジ、バックエンド、SwiftUI。
- Investigated: `ios/build/generated/ios/ReactCodegen/RCTModuleProviders.mm` は `NativeLiquidGlassModule → LiquidGlassModule` を正しく生成し、Podfile.lock も `LiquidGlass (0.8.0)` を含む。対して、`libLiquidGlass.a` には `_OBJC_CLASS_$_LiquidGlassModule` が存在するのに、最終アプリ binary には文字列／シンボルが無く、`NSClassFromString` で検出する codegen provider が空になる static-library dead-strip と判断した。
- Changed: Podfile の post-install で `MemoraRN` target の `OTHER_LDFLAGS` に `-force_load $(PODS_CONFIGURATION_BUILD_DIR)/LiquidGlass/libLiquidGlass.a` を付与するようにした。`pod install` 後の `xcodebuild -showBuildSettings` で展開済みの force-load path を確認した。この設定は Pod install 後にも残る。
- Verification: `pod install` passed。通常 DerivedData は別プロセスの build DB lock で失敗。今回作成した `/tmp` DerivedData 約6GBを安全に削除して空き容量を 2.8GB→9.0GB に回復後、TTY の isolated iOS build が **exit 0**。Simulator へ新しい Dev Client を再インストールし、Home と File Detail 要約タブが描画されることをスクリーンショット確認した。`npm run typecheck` は前回成功。Web export は同時 Metro 環境で停滞したため、この復旧後には未再確認。
- Next: File Detail の more/export sheet を手動または較正済みタップで開き、バックドロップ・下スワイプ閉じまで確認する。次に `npm run typecheck` と Web export を再実行して、この native recovery batch の最終検証を揃える。

### 2026-07-12 Metro／Simulator 復旧と `identityservicesd` 通知ループの切り分け

- やること: 外部ボリューム再マウント後に Metro と Simulator を正常状態へ復帰し、File Detail のリッチシート確認を再開する。変更ファイル: 移行ログのみ。変更しないファイル: アプリ実装、STT コア、`MemoraNative` ブリッジ、バックエンド、macOS 設定。
- Investigated: 旧 Metro プロセスは外部ボリューム切断時に cwd を失っており、packager status は返す一方で iOS bundle を返せない状態だった。`identityservicesd` の最新 crash report は `EXC_BAD_ACCESS (SIGBUS)` と `Object has no pager because the backing vnode was force unmounted` を示し、対象 Simulator（UDID `458A23AB-B4A3-43BF-8F40-4D6F56903088`）内プロセスであることを確認した。これは Memora コードや macOS Apple ID の恒久障害ではない。
- Changed: 壊れた Metro を停止し、`npm run start -- --port 8089 --lan --clear` で LAN 到達可能な 8089 に再起動。通知ループを止めるため Simulator を Shutdown してから同じ UDID を起動し直した。データ消去・端末 erase・macOS 設定変更は行っていない。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB bundle）。Simulator は正常 boot 完了後、Dev Client から Metro `http://192.168.86.26:8089` に接続し、Memora Home と File Detail 要約タブをスクリーンショットで確認した。File Detail の「その他」「ファイルを共有」は accessibility tree で検出できた。一方で Dev Client の常駐 Tools ボタンが上端「その他」と重なり、`FloatingBottomSheet` の提示／バックドロップ／下スワイプ閉じは未確認。
- Next: Dev Client Tools ボタンを非表示にして、File Detail の「その他」「書き出す」シートをそれぞれ表示し、バックドロップと下スワイプの閉じ操作を実機確認する。

### 2026-07-12 File Detail 2シートの実操作確認（Claude・未達）

- やること: Codex 引き継ぎの `FloatingBottomSheet`（その他／書き出す）を Simulator で提示・バックドロップ閉じ・下スワイプ閉じまで確認する。変更ファイル: 移行ログのみ（コード変更なし）。変更しないファイル: STT コア、`MemoraNative` ブリッジ、バックエンド、SwiftUI。
- Verified（read-only + typecheck）: `apps/mobile-expo/src/components/FloatingBottomSheet.tsx`（`BottomSheetModal` + `enablePanDownToClose` + backdrop `pressBehavior="close"` + `enableDynamicSizing` + `handleComponent={null}`）実在。`FileDetailScreen.tsx` 390-397/401-420 が `FloatingBottomSheet` で その他／書き出す を表示、要約タブに添付グリッド（233-255）実装。`app/_layout.tsx` は `GestureHandlerRootView` → `BottomSheetModalProvider` 配線済み。`ios/Podfile` 81-84 に LiquidGlass `-force_load`。`npm run typecheck` passed。
- Investigated（Simulator）: アプリ再起動で最新 JS の File Detail をロード（ヘッダー・中央タブ・添付グリッドを実スクショ確認）。Dev Client 常駐 Tools ボタンが上端「その他」に重なることを実証（共有アイコン相当座標のタップで Tools メニューが開いた）。dev メニュー内に「Tools button」非表示トグルを発見。Metro 接続 `http://192.168.86.26:8089` を確認。
- Blocked（§F）: `cliclick` は大ターゲット（Tools ボタン開閉、back ナビ、Tools ボタンの**ドラッグ退避**）は成功する一方、右上の小アイコン（共有／その他、約30–40px）と dev メニューのトグルを安定タップできない。Tools ボタンをドラッグで下部へ退避してヘッダーの重なりを解消した後も、x=1350〜1412 / y=180〜210 の計6点で共有／その他タップが全て不発。**よって2シートの提示／バックドロップ閉じ／下スワイプ閉じは未確認のまま。** 未確認を確認済みと報告しない方針に従う。
- Next: 人手（実機 or インタラクティブ Simulator）で「…」「共有」をタップしてシート提示・バックドロップ・下スワイプ閉じを確認（人手なら容易）。または XCUITest / Maestro など堅牢な自動化へ切替。dev メニューの「Tools button」を手動オフにすれば重なりは恒久解消できる。確認後に Home／Tasks の共通 Bottom Sheet 移行を別バッチとして判断。

### 2026-07-12 File Detail 2シートの実操作確認（続き・部分達成）

- やること: 上記の未達を解消し、「書き出す」「その他」シートの提示／バックドロップ閉じ／下スワイプ閉じを実際に確認する。変更ファイル: 診断のため `FileDetailScreen.tsx` を一時的に編集（`{false&&}` での無効化、`Alert.alert` 挿入）→ **すべて元のコードに復元済み**、最終的な差分はゼロ。移行ログのみ実質更新。変更しないファイル: STT コア、`MemoraNative` ブリッジ、バックエンド。
- タップ座標較正をやり直した: `back` chevron と Home タブバーの「タスク」アイコンの実ピクセル位置（PIL で検出）と、それぞれを開いたcliclick座標から線形変換を逆算し直し、以降はこの式で全アイコン座標を算出。この式は「タスク化」ボタン（V6の小さいタッチターゲット）のタップにも成功し、他画面でも再現性を確認——**座標較正自体は正しいことを確認した。**
- 診断の結果、`share`/`その他` の `onPress` は正しく発火することを一時的な `Alert.alert` 挿入で実証。さらに `isExportOpen` が `true` になった状態で **「書き出す」シートが実際に描画されることを1回、明確に確認した**（フローティングカード＋グラブハンドル＋Notion/ChatGPT/Markdown の3行）。続けて**バックドロップ（暗転部分）タップでシートが正しく閉じることも確認した**（閉じた後の画面がクリーンな状態に戻ることをスクショで確認）。
- **ただし再現性が低い**: 同じ座標・同じコードで繰り返しテストすると、シートが開かない試行が複数回発生した（`より` シートは複数回とも不開、`書き出す` シートも一部の試行で不開）。原因は特定できず、`cliclick` によるOS合成タップ（本物のタッチイベントではなくマウスイベント経由）の不安定性（既存の §F 課題）である可能性が高いが、`BottomSheetModal.present()` 呼び出し自体のタイミング起因の可能性も否定できない。下スワイプ閉じは合成タップでは検証手段がなく**未確認のまま**。
- 診断用の一時編集（`{false&&}` での無効化、`Alert.alert` 挿入）はすべて削除・復元済み。`npm run typecheck` passed、`npx expo export --platform web` succeeded。コードは元の状態と完全に一致（diff ゼロ）。
- 結論: **書き出すシートの「提示」と「バックドロップ閉じ」は実機能として動作することを実証した**（1回の明確な成功、コード上の欠陥は見当たらない）。ただし合成タップでの再現性が低いため、「常に確実に開く」とまでは断言できない。下スワイプ閉じと「その他」シートの提示は依然未確認。 | `npm run typecheck` passed; `npx expo export --platform web` succeeded。 | 実機または人手のインタラクティブ Simulator で最終確認すること。再現性の問題が実機でも起きるなら、`FloatingBottomSheet`/`BottomSheetModal` 側の初期化タイミング（ref 準備前の `present()` 呼び出し等）を疑って調査する。

### 2026-07-13 File Detail 2シートの再現性修正 + シート／ダイアログの視認性改善

- やること: File Detail の「その他」「書き出す」が不定期に提示されない原因を特定・修正し、シート→後続モーダルの競合も解消する。追加のユーザー指示により、ボトムシート／ダイアログだけ透過度を下げる。変更ファイル: `FloatingBottomSheet.tsx`、`FileDetailScreen.tsx`、`HomeScreen.tsx`、`TasksScreen.tsx`、移行ログ。変更しないファイル: タブバー、STT コア、`MemoraNative`、バックエンド、SwiftUI。
- Root cause: `FloatingBottomSheet` の effect は初回 `isOpen=false` でも `ref.current?.dismiss()` を呼んでいた。`@gorhom/bottom-sheet` v5.2.14 の実装では初期 `MODAL_STATUS.INITIAL` への dismiss が `DISMISSING` を設定し、bottom sheet ref が未マウントなら unmount callback まで進まない。後続 `present()` 時も Portal render が `DISMISSING` を理由に拒否できるため、前セッションの「同一コードで開いたり開かなかったりする」症状と一致する。
- Changed (`FloatingBottomSheet.tsx`): `isPresentedRef` を追加し、実際に `present()` を呼べたシートだけを dismiss するよう修正。`onDismiss` で ref を確実に戻す。`index={0}` を明示し、`handleComponent={null}` を廃止してライブラリ標準の gesture handle（36×4）を使用。親の `accessible` grouping を無効にし、子の操作行が個別 button として UI automation／VoiceOver に露出するようにした。
- Changed (`FileDetailScreen.tsx`): その他／書き出す行の action を ref に保留し、Bottom Sheet の `onDismiss` 完了後にリネーム、削除確認、未接続 Alert、Share を起動する方式へ変更。シート閉じアニメーション中に別 Modal を提示するレースを除去した。ヘッダー3操作とシート行へ `accessibilityRole="button"` を追加。履歴コメントを削除。診断用の大ボタンは検証後に完全撤去済み。
- Visibility decision: ユーザーの新しい明示判断により、タブバーの白・高透過は維持しつつ、File Detail／Home／Tasks のシートは `effect="regular"` + 白 `tintColor=0.78`、File Detail の削除／リネームダイアログは白 tint 0.82、シート内部の行／入力面は白 0.86 に変更した。iOS<26 の `sheetFallback` は従来どおり全箇所に併記。
- Verification: 各変更後に `npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB）。一時診断ボタンを使った確認後、XcodeBuildMCP の runtime UI snapshot で本番ヘッダーの「その他」「ファイルを共有」と全シート行を button として取得。両シートを複数回提示し、backdrop で閉じた後も再提示できることを確認した。「その他→削除確認」と native file の「その他→タイトル変更」は Bottom Sheet が消えた後に RN Modal が表示されることをスクリーンショット確認。透過度変更後の File Detail 書き出し／削除ダイアログと Tasks 追加シートを目視し、背後の文字干渉が解消したことを確認。Home シートの目視は未確認。
- Pan-down limitation: Computer Use の mouse drag は touch pan にならず、XcodeBuildMCP の runtime drag も `FBSimulatorHIDEvent does not support touch move events` で失敗した。標準 handle gesture と `enablePanDownToClose` のコード経路は復元済みだが、下スワイプ閉じだけは人手または実機タッチで未確認。確認済みとは報告しない。
- Dev menu: `EXDevMenuTouchGestureEnabled=0`、`EXDevMenuMotionGestureEnabled=0` を読み取り確認。Tools FAB は左下へ退避済みで、今回の検証を妨げないため false のまま維持した。アプリ機能の gesture 設定ではない。
- Next: 人手／実機で標準 handle の下スワイプ閉じを確認。次の独立バッチで Home／Tasks の自作 Modal を `FloatingBottomSheet` へ移行し、同時に `SheetCard` を抽出するか判断する。

### 2026-07-13 Home／Tasks の共通 FloatingBottomSheet 移行

- Changed: `SheetCard` を抽出し、白 tint 0.78 の `regular` Liquid Glass、iOS<26 fallback、黄金比 radius 21、既定の左右／下マージンを共通化した。Home のフィルターとファイル操作、Tasks の追加を、手組み `Modal` から `FloatingBottomSheet` へ移行した。File Detail の「その他」「書き出す」も同じカードへ置換した。
- Files touched: `apps/mobile-expo/src/components/SheetCard.tsx`、`apps/mobile-expo/src/components/V6AudioFileRow.tsx`、`apps/mobile-expo/src/screens/HomeScreen.tsx`、`apps/mobile-expo/src/screens/TasksScreen.tsx`、`apps/mobile-expo/src/screens/FileDetailScreen.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1560 modules）。Simulator で Home filter sheet を表示し、白いカードの視認性と backdrop close を確認。Tasks add sheet も入力欄・追加ボタンを含むカード表示と backdrop close を確認した。データ追加／削除は実行していない。
- Decisions: シート内容面の視認性は `SheetCard` に一本化する。タブバーの高透過は変更しない。Home の rename/move/delete はシート dismiss 完了後に起動し、RN Modal の提示競合を避ける。Tasks の keyboard 追従は引き続き RN 標準 `KeyboardAvoidingView` とする。
- Blockers: Home ファイル行は nested Pressable が runtime accessibility tree 上で親行へ統合され、今回の自動タップでは「…」だけを選択できなかったため、ファイル操作シートと後続ダイアログは未確認。Simulator の touch-move 非対応により pan-down close も未確認。
- Next: 人手／実機で Home 行「…」→操作シート→rename/move/delete confirm を確認し、標準 handle を下へスワイプして閉じることを確認する。

### 2026-07-13 Home ファイル行の独立「…」操作とシート遷移確認

- Changed: `V6AudioFileRow` の外側を単一 `Pressable` から `View` に変更し、ファイルを開く領域と44pxの末尾操作ボタンを兄弟要素へ分離した。nested Pressable を解消し、タイトル・メタ・要約・処理進捗のレイアウトは維持した。
- Files touched: `apps/mobile-expo/src/components/V6AudioFileRow.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1560 modules）。Simulator runtime UI でファイル本体と「…」を別々の button として取得。「…」から白い Home 操作シートを表示し、「削除」選択後にシートが閉じてから中央の削除確認ダイアログが表示されることをスクリーンショット確認した。削除ボタンは押しておらず、データは変更していない。
- Decisions: 行内の副操作は nested Pressable に戻さず、独立した44pxタッチ領域を維持する。
- Blockers: Simulator HID が touch move を提供しないため、標準 handle の pan-down close は未確認。
- Next: 実機または人手の Simulator 操作でシートを下へスワイプして閉じることを確認する。タイトル変更／プロジェクト移動は同じ dismiss 後 action 経路だが未確認。

### 2026-07-13 Home 操作経路の残確認とアクセシビリティ補完

- Changed: Home ヘッダーの接続デバイス／検索／設定、プロジェクトカード、削除確認のキャンセル／削除に `accessibilityRole="button"` を追加した。表示や処理内容は変更していない。
- Files touched: `apps/mobile-expo/src/screens/HomeScreen.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1560 modules）。Simulator で「タイトルを変更」と「プロジェクトに移動」をそれぞれ選び、Bottom Sheet が閉じた後に正しい案内 Alert が表示されることを確認。runtime UI で接続デバイス／検索／設定が独立 button として取得できることも確認した。データは変更していない。
- Decisions: アイコンだけの操作も明示 label + role を持たせる。未接続機能の案内文と所有権は変更しない。
- Blockers: pan-down close は実タッチ未確認のまま。
- Next: 写真付き実データで File Detail 添付グリッドを確認する。データ準備が難しい場合は、再ビルドを伴うフォント永続化または Xcode の EXConstants test-target 診断へ進む。

### 2026-07-13 File Detail 添付追加タイルと操作 role の確認

- Changed: File Detail の固定質問バーへ button role、要約／文字起こし／メモへ tab role と selected state、チャプター行とタスク化へ button role を追加した。表示・データ契約・写真保存処理は変更していない。
- Files touched: `apps/mobile-expo/src/screens/FileDetailScreen.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1560 modules）。`weekly-growth-0709` を Simulator で開き、要約タブをスクロールして「添付」「Ask AI が内容を読み取ります」、破線の追加タイル、Pro ストレージ案内をスクリーンショット確認。追加タイルをタップするとメモタブへ遷移し、メモ入力面と「写真を添付」面が表示されることを確認した。
- Decisions: 写真付き状態を作るためだけに既存 memo/photo 保存領域へテストデータを書かない。既存メモ写真を唯一の正本として再利用する判断を維持する。
- Blockers: 現在の fixture と Simulator データに写真がないため、3列サムネイルと「この端末のみ」バッジの目視は未確認。スクロール／タブアニメーション直後の1フレームで XcodeBuildMCP screenshot が黒く欠けたが、静止後の再取得は正常だった。
- Next: 実データに写真が追加された時点でサムネイルと端末内バッジを確認する。次は再ビルド前提のフォント永続化、または Xcode test-target の EXConstants 修復を独立バッチで進める。

### 2026-07-13 フォント選択の AsyncStorage 永続化

- Changed: Expo SDK 57 互換の `@react-native-async-storage/async-storage` 2.2.0 を導入。`/dev-fonts` は `memora.dev.selected-font` に候補キーを保存し、画面起動時に候補一覧で検証して復元する。読込完了までは loading を維持し、読込／保存失敗は画面内 alert として表示する。閉じる／候補チップの role とチップの selected state も追加した。
- Files touched: `apps/mobile-expo/package.json`、`apps/mobile-expo/package-lock.json`、`apps/mobile-expo/ios/Podfile.lock`、Pods/codegen 生成物、`apps/mobile-expo/src/screens/DevFontPreviewScreen.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。`pod install` succeededし、RNCAsyncStorage 2.2.0 の autolink/codegen を確認。XcodeBuildMCP `build_run_sim` は warnings のみで build/install/launch 成功。Simulator で Noto Sans JP を選択し、アプリを terminate/launch 後に `/dev-fonts` を開き直しても Noto Sans JP の黒い選択チップと同フォントの preview が復元されることをスクリーンショット確認した。
- Decisions: 保存対象は開発用フォントプレビューの候補キーだけとし、アプリ全体の typography を動的に差し替える機能には拡張しない。未知／削除済みキーは system 候補へ安全にフォールバックする。
- Blockers: なし。npm は既存を含む moderate vulnerabilities 10件を報告したが、この依存追加バッチでは `npm audit fix` を実行していない。
- Next: `MemoraRNTests` の EXConstants build-for-testing 回帰を Xcode で診断し、テストターゲットを復旧する。

### 2026-07-13 EXConstants QA 復旧確認 + DerivedData の HIKSEMI 移行

- Changed: `apps/mobile-expo/scripts/ios-qa.sh` の既定 DerivedData を一時ディレクトリから `apps/mobile-expo/.expo/ios-qa-derived-data` へ変更した。リポジトリの物理配置が HIKSEMI のため、QA ビルド成果物は外部ディスクへ保存される。XcodeBuildMCP も永続設定 `.xcodebuildmcp/config.yaml` で `apps/mobile-expo/.expo/xcodebuildmcp-derived-data` を使うようにした。
- Files touched: `apps/mobile-expo/scripts/ios-qa.sh`、ローカル専用 `.xcodebuildmcp/config.yaml`、`.gitignore`、本移行ログ。絶対パスを含む XcodeBuildMCP 設定は Git 対象外にした。STT コア、`MemoraNative`、バックエンド、SwiftUI は変更していない。
- Verification: 最初の `build-for-testing` は EXConstants ではなく、内蔵ディスク空き 116MiB による `write64 errno=28` で失敗した。今回生成した `/tmp/memora-rn-qa-diagnose` 1.8GiB と `~/Library/Developer/XcodeBuildMCP/workspaces/Memora-8cec9db41afd/DerivedData` 2.8GiB のみ削除し、内蔵空きを 4.7GiB へ回復。HIKSEMI 上の新規 DerivedData で、指定 Simulator に対する `npm run qa:ios:build` と `npm run qa:ios:test` がともに exit 0。EXConstants の build-for-testing 回帰は再現しなかった。QA DerivedData は 2.9GiB、HIKSEMI 空きは 179GiB。`npm run typecheck` passed、`npx expo export --platform web` succeeded（3.1MB、1566 modules）。
- Decisions: Xcode 標準 DerivedData と QA 固有の DerivedData は外部ストレージへ配置する。Simulator runtime／Apple 管理キャッシュは無理に移動しない。
- Audit: moderate 10件は Expo SDK 57 の `@expo/config-plugins` → `xcode@3.0.1` → `uuid@7.0.3` 依存鎖。`npm audit fix --force` が提示する Expo 46.0.21 への downgrade は SDK 57 アプリを壊すため不採用。現行互換範囲で安全な自動修正はない。
- Blockers: 共通 Bottom Sheet の pan-down close は Simulator HID 制約により実タッチ未確認のまま。内蔵ディスクは 4.7GiB まで回復したが、Simulator runtime 等で再び増える可能性はある。
- Next: 実機または人手タッチで pan-down close を確認する。容量が再減少した場合は、まず XcodeBuildMCP／QA のパスが外部を指していることと、Simulator runtime／ログの増加量を読み取り診断する。

### 2026-07-13 未使用Simulatorランタイム削除

- Changed: Apple管理のsecure runtime storageから、30日以上未使用だった iOS 26.0 beta（23A5260l、9.3GB）と iOS 26.2（23C54、7.8GB）を `xcrun simctl runtime delete` で削除した。Memoraのソースコード／設定ファイルは変更していない。
- Files touched: Apple管理のSimulator runtime／関連dyld cache、本移行ログ。使用中のiOS 26.5、iOS 26.0正式版、HIKSEMI上の `~/Library/Developer/CoreSimulator` 端末データ、STTコア、`MemoraNative`、バックエンドは変更していない。
- Verification: 削除前に `--notUsedSinceDays 30 --dry-run` で上記2件だけが候補になることを確認。削除後の `xcrun simctl list runtimes` はiOS 26.0正式版とiOS 26.5のみ。内蔵空きは4.7GiBから29GiBへ増加し、`/Library/Developer/CoreSimulator/Caches` は15GBから6.9GBへ減少した。`Memora RN Test`（UDID `458A23AB-B4A3-43BF-8F40-4D6F56903088`）はiOS 26.5でBootedのまま。`npm run typecheck` passed、`npx expo export --platform web` succeeded。
- Decisions: `/System/Library/AssetsV2` のsecure runtime storageはsymlinkで外部化せず、Apple公式の削除経路だけを使う。iOS 26.0正式版は2026-07-05に使用履歴があるため保持する。
- Blockers: なし。HIKSEMIを外した状態では外部化済みSimulator端末データを利用できない。
- Next: iOS 26.0正式版が不要と確認できた場合のみ追加削除する。それまではiOS 26.5をMemoraの標準検証環境として維持する。

### 2026-07-13 Tasks 追加シートの状態リセットとアクセシビリティ補完

- Changed: タスク追加シートの閉じる経路を共通化し、追加完了・backdrop close・シートを下げて閉じる場合のいずれでも下書き入力を破棄するようにした。テキスト入力のキーボード完了でも追加できる。タスク完了は checkbox と checked state、参照元は link、完了一覧は expanded state を持つ個別アクセシビリティ操作にした。
- Files touched: `apps/mobile-expo/src/screens/TasksScreen.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。
- Decisions: タスクは現時点で画面内の mock state とし、永続化や SwiftData/ネイティブブリッジへの接続は行わない。シートを閉じる操作は保存ではなくキャンセルとして扱う。
- Blockers: Bottom Sheet の pan-down close は Simulator の touch-move 制約により実タッチでは未確認。状態リセットは共通 `onClose` 経路で保証する。
- Next: 実機または人手の Simulator 操作で標準 handle の pan-down close を確認する。タスクの永続化は正本となるデータ契約が決まってから独立バッチで扱う。

### 2026-07-13 Home UI/UX P0: 状態整合・削除フィードバック・再試行

- Changed: Home ヘッダーのデバイス状態をライフログと同じ未接続へ統一し、接続済みと誤認させる表示を除去した。削除確認は削除中に両操作を無効化し、処理中ラベルを表示して多重実行を防ぐ。読み込み失敗カードには再試行操作を追加した。
- Files touched: `apps/mobile-expo/src/screens/HomeScreen.tsx`、`apps/mobile-expo/src/components/StateViews.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。
- Decisions: 実デバイス接続の正本となるブリッジ契約がないため、UIだけで接続済みを推測しない。削除の undo は永続ストレージの復元契約が未確定のため追加しない。
- Blockers: 実デバイス接続状態および削除失敗の強制再現は未確認。共通 Bottom Sheet の pan-down close も実タッチ未確認のまま。
- Next: P1として、検索と Ask の入口分離、未接続機能の事前明示、プロジェクト詳細導線を独立バッチで扱う。

### 2026-07-13 UI polish: 開発表示とAIテンプレ感の低減

- Changed: Home の `native-recording-*` を「新しい録音」として表示し、ネイティブモジュール／SwiftData 配線に言及する内部英文を一覧から隠した。Ask は「聞く」へ日本語化し、新規会話を44pxの編集アイコンへ整理、質問例を灰色カードから区切り線付きのフラットな行へ変更、参照元チップと未接続 Alert の開発者向け文言も簡素化した。Tasks は大きな薄灰色の追加ボタンをヘッダーの44px操作へ移し、開発作業fixtureを一般的な会議タスクへ置換。Settings は各グループの灰色角丸面を外し、白地・余白・区切り線で階層化した。
- Files touched: `apps/mobile-expo/src/components/V6AudioFileRow.tsx`、`apps/mobile-expo/src/screens/AskAIScreen.tsx`、`apps/mobile-expo/src/screens/TasksScreen.tsx`、`apps/mobile-expo/src/screens/SettingsScreen.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。Simulator で Home／Ask／Tasks／Settings の変更後表示をスクリーンショット確認。Tasks はアプリを完全終了・再起動し、新しい日本語fixtureとヘッダー追加操作が表示されることを確認した。
- Decisions: V6 の黒白基調、最小44pt操作領域、タブバーの白／高透過と黄金比ルールは維持。UI Pro Max の汎用配色／英字フォント案は正典より優先せず、カード乱用・弱い階層・開発文言露出の監査だけに利用した。
- Blockers: 実機での最終余白確認は未実施。Simulator のXcodeBuildMCP Toolsボタンは検証用オーバーレイでありアプリUIではない。
- Next: 実機で4画面を確認後、File Detail と録音／生成フローを同じ「装飾を減らし、情報階層を強める」基準で監査する。

### 2026-07-13 UI polish: File Detail と録音後の生成表現

- Changed: File Detail の固定質問バーを Sparkles + 「このファイルについて質問する」から会話アイコン + 「この記録について聞く」へ変更。次のアクションは反復する枠付き「タスク化」を、補助色の `＋ タスク` 操作へ軽量化。添付説明は `Ask AI` の機能名を前面に出さず「質問時に参照されます」とした。録音後の画面は中央の装飾アイコン列を除去し、見出し／説明を「文字起こしと要約」「録音から要点と次のアクションを整理します」に短縮。モード名を「自動／テンプレート」、設定行を「要約モデル」、CTAを「処理を開始」へ変更した。
- Files touched: `apps/mobile-expo/src/screens/FileDetailScreen.tsx`、`apps/mobile-expo/src/features/capture/CaptureFlowProvider.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。Simulator の File Detail 要約タブで、軽量化したタスク操作と会話アイコンの固定質問バーをスクリーンショット確認。
- Decisions: `generateSummary`、テンプレートID、provider、録音停止後の状態遷移は変更しない。AIを隠すのではなく、画面の主語をモデル名からユーザーの作業へ移した。
- Blockers: 録音後の選択画面は実録音を開始していないため変更後の目視未確認。コード上の表示と型検査／bundleのみ確認済み。
- Next: 実機で短い録音を1件作り、停止後の「文字起こしと要約」画面の余白とCTAを確認する。

## Visual Review Notes

### 2026-07-13 Home UX: 検索とプロジェクト導線

- Changed: Home の検索アイコンを Ask AI 遷移から、タイトル・要約・プロジェクト名を対象とするファイル検索へ変更。一致なし状態も追加した。プロジェクトカードは先頭ファイルを直接開かず、対象プロジェクトのファイル一覧と戻る操作を表示する。検索中はプロジェクト／ライフログを重複表示しない。
- Files touched: `apps/mobile-expo/src/screens/HomeScreen.tsx`、`apps/mobile-expo/src/components/V6AudioFileRow.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。
- Decisions: プロジェクト専用の永続 route／データ契約はまだ設けず、Home 内の一時的な一覧遷移に留めた。プロジェクト内行は利用できない操作メニューを表示しない。
- Blockers: 実機は Mac から Offline のため、実機クラッシュと今回の検索／プロジェクト導線の確認は未実施。
- Next: 実機を認識でき次第、Dev Client を再導入してクラッシュログと UI を確認する。検索対象の正本は将来の SwiftData bridge 接続時に再確認する。

### 2026-07-13 再生／Ask のアクセシビリティ補完

- Changed: 再生・再生速度・シークへ role と現在値を含む label を付与し、再生ボタンを44pxへ拡大。Ask の添付、新規会話、候補質問、回答のコピー／タスク化へ role と具体的な label を追加した。
- Files touched: `apps/mobile-expo/src/components/PlayerBar.tsx`、`apps/mobile-expo/src/screens/AskAIScreen.tsx`、本移行ログ。
- Verification: `npm run typecheck` passed。`npx expo export --platform web` succeeded（3.1MB、1566 modules）。
- Decisions: 添付・コピー・タスク化の正本契約は未接続のため、今回の変更は意味付けと操作対象の拡大に限定した。
- Blockers: VoiceOver 実機確認は実機が Offline のため未実施。
- Next: 実機認識後に VoiceOver と Dev Client クラッシュを確認する。

- Home: first V6 visual-parity pass is now in place. The scaffold hero and metrics were removed; Home uses the `全ファイル` title, compact header, connection row, filter pills, red record affordance, thin file rows, and a functional bottom FAB menu. Remaining polish: inspect physical-device overlap/spacing and replace placeholder project/lifelog empty states with native data.
- File Detail: first V6 shell pass is complete with white header, metadata row, underline tabs, summary/transcript/memo panels, and file-scoped question bar. Share now opens the iOS share sheet and more opens rename when supported. The transcript progress card still gives a concrete event-stream preview without touching STT core.
- Ask AI: first V6 visual-parity pass is complete. Scope tabs, message bubbles, source chips, input composer, empty/loading states, and query behavior remain interactive. Remaining polish: replace deterministic mock answers with the real retrieval/query facade after the boundary is chosen.
- Settings: first V6 visual-parity pass is complete with dense grouped rows, black selected controls, and compact Bridge diagnostics. Non-secret controls still save through the facade. Remaining polish: wire controls to the existing Swift settings/keychain source of truth and review row spacing on device.
- Preview Index: now includes normal routes plus empty transcript and not-found states for targeted review.

## Session Completion Template

Append one entry to `Progress` and one entry to `Handoff Log` at the end of each session.

```markdown
| YYYY-MM-DD | In progress / Done / Blocked | Agent name | What changed | Commands and results | Next action |

### YYYY-MM-DD

- Changed:
- Files touched:
- Verification:
- Decisions:
- Blockers:
- Next:
```
