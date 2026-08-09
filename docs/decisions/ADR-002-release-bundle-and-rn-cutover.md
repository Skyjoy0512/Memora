# ADR-002: 1.0リリース対象（SwiftUI）とRN移行のcutover gate

- 状態: 採用
- 日付: 2026-08-03

## 決定

Memora 1.0のApp Store提出対象は**既存SwiftUIアプリ（Memora target）**とする。

`apps/mobile-expo`のReact Native/Expo版は段階移行中であり、本ADRで定義する**cutover gateを全て満たすまで提出対象にしない**。提出対象の切替は gate 通過後に改めてADRで決定する（下記 gate f）。

## 理由

- 現行のSwiftUIアプリは録音・STT・要約・検索・書き出しなどの実機能が動き、`docs/app-store-review-readiness.md`の提出準備（B1〜B6）も進行中で、審査に出す現実的なバンドルはSwiftUI側だけ。
- RN版を1.0に含めるbig-bang切替は、段階移行の途中状態（mock認証・mock課金・未到達の機能）をそのまま審査に晒すリスクがあり、現行のデータ保存（SwiftData）と機能を守りながら進める方針に反する。
- README.mdはSwiftUIを現行アプリ、RNを段階移行版とし、`docs/react-native-expo-migration-plan.md`もSwiftUIをparity証明まで維持する前提である。本ADRはこの認識を1.0の決定として固定する。

## RN cutover gate（観測可能な条件）

RN版を提出対象に切り替えるには、以下を全て満たし、その証拠を記録すること。主観的な「できた」ではなく、実機・CI・テスト結果で観測できる形で判定する。

- a. **core parity**: 録音（record）/インポート（import）/再生（playback）/STT/要約（summary）/検索（search）/書き出し（export）がRN版でSwiftUIと同等に動作する。
- b. **production data**: SwiftData移行とロールバックが実データ・実機で検証済み。既存ユーザーのデータを壊さないこと。
- c. **release到達不能化**: releaseビルドで mock fallback、fake auth/paywall、developer UI が到達不能であること（SwiftUI 1.0で行ったB1/B2相当の対応がRN版でも完了していること）。
- d. **privacy/security/readiness**: Privacy Manifest、Keychain、バックグラウンド録音申告、`ITSAppUsesNonExemptEncryption`、App Privacyなど`docs/app-store-review-readiness.md`の項目がRNバンドルに対して満たされていること。
- e. **QA/CI**: typecheck / web export / RN iOSビルド（`qa:ios:build`）/ 共有パッケージテスト（`swift test --package-path Packages/MemoraSharedData`）/ 実機QA が全て pass していること。
- f. **明示的な決定**: 上記を確認した上で、改めて後続ADR（例: ADR-003）で提出targetをRNへ切り替える。

## 帰結

- SwiftUIアプリはcutover gate通過まで**usableに保つ**。既存機能の劣化・削減はしない。
- RN版の`AuthFlowScreen`等のmock認証・mock課金は**開発用に限定**し、RN提出の際はgate cでrelease到達不能化または実装を必須とする。SwiftUI 1.0の提出には直接影響しないが、gateの追跡対象として管理する。
- `docs/app-store-review-readiness.md`は1.0（SwiftUI）の現状を正本とし、本ADRを冒頭で参照する。

## 関連文書

- `docs/app-store-review-readiness.md` — 1.0（SwiftUI）の審査準備状況
- `docs/react-native-expo-migration-plan.md` — RN移行の現在地とparity方針
