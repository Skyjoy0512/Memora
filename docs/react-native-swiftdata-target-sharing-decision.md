# React Native SwiftData Target Sharing Decision

## Status

- Date: 2026-07-10
- Status: In progress — shared-store foundation implemented; schema/repository extraction pending
- Scope: React Native/Expo app access to the existing local SwiftData source of truth
- Backend: unchanged
- STT core: unchanged and protected

## Context

The Expo migration currently builds a separate iOS host target, `MemoraRN`.
The existing SwiftUI app owns `ModelContainer`, while `AudioFile`, `AudioFileRepositoryProtocol`, and `AudioFileRepository` are internal to the original app target.
The RN target therefore cannot safely import those types from the local Expo module.
The existing SwiftUI store is created at `Application Support/Memora/Memora.store`; the generated RN app has a different bundle identifier and sandbox. Linking the shared package does not make that store visible to RN.
`MemoraSharedStoreLocation` now centralizes the dedicated App Group path, `group.com.memora.shared`. Both the SwiftUI app and RN host declare that group in their entitlements; it must still be enabled for both production App IDs in the Apple Developer portal before a signed-device release.
`MemoraStoreMigration.migrateStoreAtomically(from:to:)` now creates and verifies a staged copy of the store plus existing SQLite sidecars, then moves that directory into place as one operation. The legacy store is retained as a rollback backup. If the group container is unavailable or migration fails, the SwiftUI host continues using its legacy store.

The bridge already exposes replaceable boundaries:

- `MemoraAudioFileReading`
- `MemoraAudioFileMutating`
- `MemoraRecordingImportHandling`
- `MemoraKnowledgeQuerying`
- `MemoraSummaryGenerating`
- `MemoraSettingsReadingWriting`

`MemoraNativeBridgeBootstrap.configure(...)` is the single injection point for host-side implementations.

## Options

### A. Add existing files to the RN target

Add `AudioFile.swift`, the related SwiftData model files, repository files, migrations, and required services to `MemoraRN` target membership.

Pros:

- Small initial project-configuration change.
- Reuses existing models quickly.

Cons:

- `AudioFile` has many relationships and pulls in a large model graph.
- Internal types and app-only assumptions must be made public or duplicated.
- Two targets can drift in schema, migration configuration, and store location.
- High risk of duplicate SwiftData containers and incompatible persistent stores.

Decision: reject as the default path. Use only for a short-lived spike if package extraction is blocked.

### B. Duplicate the model and repository in the RN target

Create RN-specific copies of the SwiftData models and map them into bridge DTOs.

Pros:

- RN target can build independently.
- No immediate access-control changes in the original app.

Cons:

- Creates a second source of truth.
- Requires a migration/synchronization policy.
- Local recordings and edits can diverge between SwiftUI and RN.

Decision: reject. This would undermine the migration goal.

### C. Extract a shared Swift package/framework

Move the shared SwiftData schema, repository protocol/implementation, DTO adapters, and migration configuration into a local package or framework consumed by both app targets.

Pros:

- One schema and one repository implementation.
- Explicit public boundaries for RN host injection.
- Testable without importing SwiftUI views.
- Keeps the Expo module independent from app-target internals.

Cons:

- Largest upfront change.
- Requires careful model/schema migration validation.
- Existing app imports and target membership need a staged conversion.

Decision: recommended production path.

### D. Keep local SwiftData behind a host service and expose HTTP/API only

Use the unchanged backend for RN data and leave SwiftData accessible only to the old SwiftUI app.

Pros:

- Lowest iOS target-sharing risk.
- Fastest path for remote/shared data.

Cons:

- Does not expose existing on-device local recordings automatically.
- Requires backend/API parity for files, transcripts, summaries, and Ask AI.
- Offline behavior changes significantly.

Decision: acceptable fallback if local-data parity is explicitly deferred. Do not claim full local SwiftData migration in this mode.

## Recommended rollout

1. Define a shared package target containing only model/schema/repository contracts and DTO mapping. Do not move SwiftUI views or STT services.
2. Add a package-level `MemoraAudioFileStore` adapter that conforms to the existing public bridge protocols.
3. Keep `ModelContainer` creation in the host target initially, but pass the container/context into the adapter through an explicit initializer.
4. Make the original SwiftUI app consume the package before enabling RN real-data mode. The SwiftUI host now creates new stores in the shared group and performs the guarded one-time migration described above.
5. Update `MemoraNativeBridgeBootstrap.configure(...)` to inject the shared adapter and report `sourceDescription = "swiftdata"`.
6. Validate store URL, schema version, relationships, rename/delete, recording/import, summary, and Ask AI query behavior before cutover.

## Guardrails

- Do not import `Memora/Core` app-target internals directly from `modules/memora-native`.
- Do not duplicate the SwiftData schema in the RN target.
- Do not change STT protected files as part of target sharing.
- Do not mark `isRealDataConnected` true until the shared adapter reads the same persistent store used by the target under test.
- Do not reuse `group.com.memora.broadcast` for the SwiftData store without an explicit App Group migration design; it currently belongs to the broadcast extension path.
- Treat moving `Memora.store` into the new shared App Group as a separate data migration with backup/rollback validation. The current host implementation uses a staged, verified copy and retains the source store; it must still run while the source store is closed.
- Keep provider secrets and Keychain access in Swift host-side services.
- Keep this work separate from RN UI changes and separate from STT changes.

## Acceptance criteria

- Both SwiftUI and RN host targets compile against the same shared schema/repository package.
- A pre-existing `AudioFile` is visible from RN without data copy or mock fallback.
- RN rename/delete updates the same persistent store visible to SwiftUI.
- The bridge diagnostics report `audioFileSource = "swiftdata"` and `audioFileMutationSource = "swiftdata"` only after the above checks pass.
- Existing migration and STT tests remain green.

## Handoff

The current RN bridge is intentionally ready for injection but still uses native-file/sample implementations.
The first skeleton now exists at `Packages/MemoraSharedData` and is registered as a local package dependency of both the existing `Memora` target and the RN host target. It contains a bridge-safe audio record DTO, store contract, and test-only-friendly in-memory implementation; it intentionally does not contain `@Model`, `ModelContainer`, migrations, or STT/provider code.
The existing SwiftUI target now has `MemoraSharedAudioFileStoreAdapter`, which maps `AudioFileRepositoryProtocol` to the shared contract and reports `sourceDescription = "swiftdata"`. It is intentionally host-side and is not imported by the Expo module.
The shared App Group store foundation is now enabled in source for the SwiftUI and RN hosts. It deliberately does not turn on RN real-data mode: `AudioFile` models, schema configuration, and the repository still live in the original app target. The next implementation batch should extract the shared schema/repository boundary, add focused adapter tests, and then inject the same repository/model context into the RN host before enabling the adapter there.
