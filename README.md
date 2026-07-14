# Memora - iPhone 議事録・文字起こし・要約アプリ

![iOS](https://img.shields.io/badge/iOS-17+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-red.svg)

## 現在の実装

- iOS 17 以上向けの SwiftUI アプリです。SwiftData、録音・音声インポート、文字起こし、要約、話者分離、検索・エクスポートの実装を含みます。
- `apps/mobile-expo` に React Native / Expo の段階移行用アプリがあります。ネイティブブリッジは、アプリ sandbox の音声・JSONメタデータと非機密の UserDefaults 設定を扱います。既存 SwiftData、STT、Keychain、AI プロバイダーは未接続です。
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

- [文字起こしコア境界](docs/transcription-core-boundary.md) - STT コアの保護ルールと拡張方針
- [React Native / Expo 移行計画](docs/react-native-expo-migration-plan.md) - RN/Expo の移行範囲・現在地・引き継ぎ
- [React Native SwiftData 共有方針](docs/react-native-swiftdata-target-sharing-decision.md) - SwiftData を安全に参照するための判断記録
- [共有 Swift Package skeleton](Packages/MemoraSharedData/Package.swift) - 共有 DTO/store 契約

## ライセンス

ライセンスはリリース時に決定予定です。
