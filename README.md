# Memora - iPhone 議事録・文字起こし・要約アプリ

![iOS](https://img.shields.io/badge/iOS-17+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-red.svg)

## 現在の実装

- `apps/mobile-expo`（React Native / Expo）を UI の正本として完全移行を進めています（[ADR-003](docs/decisions/ADR-003-rn-full-cutover.md)）。RN ホストは Swift の STT・録音・SwiftData 共有パッケージ・Keychain をネイティブブリッジで利用します。
- 既存の SwiftUI アプリ（`Memora/**`）は parity と release gate 通過まで削除対象として凍結維持します（[実行計画](docs/rn-full-cutover-execution-plan.md)）。
- Xcode プロジェクトの正本は `project.yml` です。構成を変更したら `xcodegen generate` を実行してください。

## リポジトリ構成

```
Memora/                 # iOS アプリ
MemoraTests/            # iOS テスト
apps/mobile-expo/       # React Native / Expo アプリ
Packages/MemoraSharedData/
docs/                   # 設計・移行資料
project.yml             # XcodeGen の正本
```

## セットアップ

前提条件: macOS、Xcode（iOS 17 以上の Simulator runtime を含む）、XcodeGen。

```bash
git clone https://github.com/Skyjoy0512/Memora.git
cd Memora
xcodegen generate
open Memora.xcodeproj
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
