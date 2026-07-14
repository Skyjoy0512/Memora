# Memora Expo Agent Notes

Read the exact versioned Expo docs at https://docs.expo.dev/versions/v57.0.0/ before writing Expo code.

Before changing this app, also read:

- `../../docs/react-native-expo-migration-plan.md`
- `../../CLAUDE.md`
- `../../docs/transcription-core-boundary.md` if the work is near recording, transcription, STT events, AI providers, or SwiftData.

Current role of this app:

- Expo Go / web friendly mock UI for fast visual review.
- Native bridge work is implemented and tracked in Git; keep changes aligned with the bridge contract.
- Existing Swift STT core and backend must remain untouched unless explicitly requested.
