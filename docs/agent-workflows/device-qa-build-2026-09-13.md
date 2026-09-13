# 実機QAビルド手順（個人Team・2026-09-13 確立）

## 背景

実機（Ken's iPhone / iPhone 14 Pro Max / iOS 26.6.1）へのインストールに成功した際の
作業手順。無料の Personal Team（`4R82H2PVGL`）で署名するため、リポジトリの正規設定とは
次の3点だけ異なる**検証用ローカル上書き**を使う（リポジトリは変更しない）。

## 検証用上書き（3点）

| 項目 | 正規 | 検証時の上書き | 理由 |
|---|---|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.memora.Memora` | `com.hashimoto.memora.devqa` | `com.memora.Memora` は Personal Team に登録不可（既に他チームが使用） |
| `CODE_SIGN_ENTITLEMENTS` | `MemoraRN/MemoraRN.entitlements`（App Group あり） | `.expo/device-qa/Empty.entitlements`（空） | App Group は Personal Team で署名不可。アプリは appGroup 不在時に app-sandbox ストアへ自動フォールバックする |
| `HERMES_CLI_PATH` | Pods の xcconfig 由来 | `node_modules/hermes-compiler/hermesc/osx-bin/hermesc` | Pods の xcconfig に旧パス（`/Volumes/ORICO/...`）が残存しており hermesc 解決に失敗するため |

## ビルド・インストール・起動

```bash
cd apps/mobile-expo
xcodebuild -workspace ios/MemoraRN.xcworkspace -scheme MemoraRN -configuration Release \
  -destination 'platform=iOS,id=00008120-00084D3802E3C01E' \
  -derivedDataPath .expo/ios-device-derived-data \
  -allowProvisioningUpdates \
  CODE_SIGN_ENTITLEMENTS="$PWD/.expo/device-qa/Empty.entitlements" \
  PRODUCT_BUNDLE_IDENTIFIER=com.hashimoto.memora.devqa \
  HERMES_CLI_PATH="$PWD/node_modules/hermes-compiler/hermesc/osx-bin/hermesc" \
  build

xcrun devicectl device install app --device 00008120-00084D3802E3C01E \
  .expo/ios-device-derived-data/Build/Products/Release-iphoneos/MemoraRN.app

xcrun devicectl device process launch --device 00008120-00084D3802E3C01E \
  --terminate-existing com.hashimoto.memora.devqa
```

## 初回のみ必要な端末操作

無料署名のため、初回起動前に iPhone 側で開発元を信頼する:

**設定 → 一般 → VPNとデバイス管理 → デベロッパApp → 「Apple Development: greenfieldguitar@outlook.com」→ 信頼**

## この検証ビルドの制約（QA時の注意）

- App Group（`group.com.memora.shared`）は署名していない → ストアは **app-sandbox モード**で動作。
  App Group 前提の経路（共有ストア移行・拡張との共有）はこのビルドでは検証対象外。
- Bundle ID が異なるため、既存インストールとは別アプリ扱い（データは独立）。
- 有料 Team で署名できるようになったら、正規設定（App Group あり）での再検証が必要。

## Swift コンパイルエラー修正（2026-09-13）

実機ビルドで初めて露見したエラーを修正:

- `MemoraNativeModule.swift` deleteAudioFile: `missing return` → `return` 追加
- `MemoraSharedStoreBridgeAdapters.swift`: `ownedAudioDirectories` プロパティ宣言追加・`try allRecords.map(makeDTO)`
- `MemoraSharedStoreKnowledgeQuery.swift`: `provider.generate(prompt:)` → `provider.generate(prompt)`（プロトコル定義は無ラベル）
