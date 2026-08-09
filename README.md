# Memora - iPhone 議事録・文字起こし・要約アプリ

![iOS](https://img.shields.io/badge/iOS-17+-blue.svg)
![React Native](https://img.shields.io/badge/React_Native-blue.svg)
![Expo](https://img.shields.io/badge/Expo-000000.svg)

## 現在の実装

- `apps/mobile-expo`（React Native / Expo）を UI の正本とし、RN iOS ホスト `MemoraRN` が Swift の
  STT・録音・SwiftData 共有パッケージ（`Packages/MemoraSharedData`）・Keychain をネイティブブリッジで利用します。
- SwiftUI アプリ（旧 `Memora` target）は 2026-08-09 に削除済みです（[ADR-003](docs/decisions/ADR-003-rn-full-cutover.md) 追記）。
  旧 `MemoraBroadcastExtension` / `MemoraWidget` のソースは維持します（現時点ではビルド対象外）。

## リポジトリ構成

```
apps/mobile-expo/       # React Native / Expo アプリ（UI の正本）
apps/mobile-expo/ios/   # RN iOS ホスト（MemoraRN）
Packages/MemoraSharedData/  # 共有 Swift Package（STT・スキーマ・ストア契約）
MemoraBroadcastExtension/   # Broadcast Extension ソース（ビルド対象外）
MemoraWidget/           # Widget ソース（ビルド対象外）
docs/                   # 設計・移行資料
```

## セットアップ

前提条件: macOS、Xcode（iOS 17 以上の Simulator runtime を含む）、Node.js 22。

```bash
git clone https://github.com/Skyjoy0512/Memora.git
cd Memora
cd apps/mobile-expo
npm ci
npx expo start
```

RN iOS ホスト（`MemoraRN`）のビルドは分離 DerivedData で実行します:

```bash
cd apps/mobile-expo/ios
pod install
cd ..
npm run qa:ios:build
```

## ドキュメント

- [RN完全移行の決定（ADR-003）](docs/decisions/ADR-003-rn-full-cutover.md) - SwiftUI 1.0方針をsupersedeしたRN完全移行の決定
- [RN full cutover 実行計画](docs/rn-full-cutover-execution-plan.md) - parity matrix・並列lane・checkpoint分割・削除gate・rollback
- [文字起こしコア境界](docs/transcription-core-boundary.md) - STT コアの保護ルールと拡張方針
- [React Native / Expo 移行計画](docs/react-native-expo-migration-plan.md) - RN/Expo の移行範囲・作業ログ・引き継ぎ
- [React Native SwiftData 共有方針](docs/react-native-swiftdata-target-sharing-decision.md) - SwiftData を安全に参照するための判断記録
- [共有 Swift Package skeleton](Packages/MemoraSharedData/Package.swift) - 共有 DTO/store 契約

## ライセンス

ライセンスはリリース時に決定予定です。
