# Claude Code Handoff: Memora SwiftUI to React Native / Expo

このドキュメントを最初に読み、現在の状態から作業を再開してください。ユーザーは「可能な限り自律的に、並行可能な検証は並行して進める」ことを期待しています。質問で止まらず、既存コードとこのドキュメントから安全に判断してください。

## ユーザーの目的

- SwiftUIのフロントエンドをReact Native + Expoへ段階移行する。
- バックエンド、録音、STT、AIの既存責務は維持する。
- Expo Dev Clientで実機確認しやすくする。
- Claude Code / Codex / DeepSeekなど別LLMが途中から継続できるよう、進捗と判断を文書化する。

## 現在の進捗

- 全体進捗: 約85%(2026-07-10時点。W4の実データ接続自体は進んでいないが、V6視覚検証基盤が整った)
- SwiftUI V6との画面デザイン一致度: 約82%(2026-07-10に実機相当のシミュレータで4画面すべてを検証し、File Detail/Ask AI/Home/Settingsの主要な差分を修正済み。数値ベースの微調整余地はまだ残る)
- RN画面はExpo SDK 57 / React Native 0.86 / React 19.2。
- Home、File Detail、Ask AI、Settingsの主要画面シェルはV6の白背景・黒文字・赤い録音アクセントへ寄せた。
- Homeには固定下部FABがあり、録音/取り込みの既存bridge処理を呼び出す。
- File Detailの共有はiOS標準`Share`シート、その他操作は名前変更導線へ接続済み。
- 実機 `Ken's iPhone` でDev Clientのビルド、インストール、起動、Metro接続を確認済み(2026-07-10に再確認: 起動直後にMetro(port 8089)への確立済みTCPソケット5本を確認し、ネイティブ起動だけでなくJSバンドル読み込みまで確認した具体的証拠あり)。
- Metroは現在ポート8089で起動したセッションを利用していたが、必要なら再確認する。
- iOS Simulatorは**使用可能になった**。原因は`Xcode.app`本体へのフルディスクアクセスだけでは不十分で、CoreSimulatorが個別に起動する2つのXPCサービス(`SimulatorTrampoline.xpc`と`CoreSimulatorService.xpc`)それぞれに直接フルディスクアクセスを付与する必要があった(Finderからドラッグ&ドロップで追加、`+`ピッカーには出てこない)。詳細は `docs/react-native-expo-migration-plan.md` の2026-07-10エントリを参照。
- シミュレータ`Memora RN Test`(iPhone 17 Pro, iOS 26.5, UDID `458A23AB-B4A3-43BF-8F40-4D6F56903088`)を作成・起動し、`simctl io screenshot` + `osascript`(System Events、要Accessibility権限)によるタップ自動化で、Home/File Detail/Ask AI/Settingsの4画面を実際にスクリーンショットで確認済み。
- **File Detailにヘッダー二重表示のバグを発見**: Expo Routerのネイティブスタックヘッダー(`< (tabs)` + `ファイル詳細`)と、画面自身が描画するカスタムヘッダー(独自の`<`戻るボタン + ファイルタイトル)が両方表示されている。次セッションで修正が必要。
- Home(FAB展開・タブバー非重複)、Ask AI(3スコープ切り替え)、Settings(グループ化された設定行・Bridge診断ステータスドット)は目視確認で概ねV6デザインに合致していることを確認済み。Settingsは`Omi preview`より下の内容は未確認(スクロールジェスチャーの自動化が今回未解決)。
- **File DetailとAsk AIの余白・スタイルをV6ソース実測値に合わせて修正済み(2026-07-10)**: File Detailのタイトル二重表示(Screenの32ptヘッダーとheroTitleの24ptが両方出ていた)を解消、アイコンタップ領域を40×40ptに、タブ間隔を24ptに修正。Ask AIは丸みを帯びたチャットバブル表示から、V6が明示的に採用している「プレーンなドキュメントスタイル」(バブル背景なし、質問は小さめグレー文字、回答は本文+アイコン付きソースチップ+区切り線)に書き換え。詳細は移行計画ドキュメントの該当エントリを参照。
- **Home並び順修正済み(2026-07-10)**: 接続状態行+検索/設定アイコンを1行にまとめ、タイトルの上に配置(V6と同じ順序)。`Screen`コンポーネントに`topRow`スロットを追加して対応。検索・設定アイコンのナビゲーションも問題なし。
- **Settings IA対応済み(2026-07-10)**: ユーザーの明示的な判断により、V6の構成(アカウント/デバイス/ストレージ/通知/連携/文字起こし・要約/その他/アカウント操作)をモックデータで既存のBridge診断セクションの上に追加。各行のタップは「準備中」アラートを表示し、実際には動作しないことを正直に示す(バックエンド未接続のため)。既存のBridge診断・設定編集コントロールはそのまま残っている。
- **スクロールジェスチャー自動化も解決済み(2026-07-10)**: `cliclick`のドラッグ前に`m:`移動コマンド+各ステップ間に100ms待機を入れることで動作するようになった。Settings画面の`Omi preview`より下(Bridge診断の全項目)も含めて全内容を目視確認済み、問題なし。
- 本セッション終了時点の検証結果: `npm run typecheck`通過、`swift test`6件通過、RN `build-for-testing`(generic simulator)成功、`git diff --check`クリーン。
- **File DetailのTranscript/Memoブリッジを本物のネイティブ機能として実装済み(2026-07-10)**: ユーザーが「本物のネイティブブリッジ機能として実装する」を選択。既存の録音/取り込みブリッジと同じレジストリパターンで実装:
  - Playback: `MemoraPlaybackDTO.swift` — `AVAudioPlayer`ベースの本物の再生(load/play/pause/seek/setRate/getStatus)。`PlayerBar.tsx`をTranscriptタブに追加。
  - Memo: `MemoraMemoDTO.swift` — JSON保存のメモ本文+`expo-image-picker`による写真添付。Memoタブをタップ編集+写真グリッドに書き換え。
  - **Playbackは実録音ファイルで実際に動作確認済み**(実際の長さ`02:49`が正しく表示される = 偽のフォールバックではなく本物のAVAudioPlayerが動いている証拠)。
  - **Memoタブは未検証**: 再生確認直後にSimulatorアプリのウィンドウがmacOSのアクセシビリティから見えなくなる問題が発生し(`count of windows`が0のまま、複数回のkill/relaunchでも復旧せず)、ユーザーの判断で今回は目視確認をスキップした。コードはtypecheck・Xcodeビルド共に通過済みだが、実際に動くかは次回セッションでの確認が必要。
  - 通常のアプリビルド(`xcodebuild ... build`)は繰り返し安定して成功、typecheck通過、swift test 6件通過、git diff --checkクリーン。
  - **`build-for-testing`(MemoraRNTestsターゲット)が今セッション中に壊れました**: `cannot load underlying module for 'EXConstants'` というエラーで、既存の(今回変更していない)`MemoraSharedStoreBridgeAdapterTests.swift`のコンパイルが失敗。単純な再試行・ModuleCache削除・DerivedData完全削除の3パターンすべてで再現(DerivedData削除後の再ビルドはCPU使用率がほぼ0のまま長時間進まず、強制終了した)。`expo-image-picker`追加後の`pod install`が引き金になった可能性が高いが未確定。**アプリ本体の動作には影響なし**(実際に動くことは確認済み)だが、テストターゲットのビルド健全性としては未解決の回帰。
- 次回セッション最優先: (1) `build-for-testing`/EXConstants回帰の調査(Xcode.appを直接開いて詳細診断を見るのが早い)。(2) Simulatorウィンドウの復旧(Mac再起動が有効な可能性が高い)→ Memoタブの目視確認(テキスト編集保存、写真の追加・削除)。
- それ以外は移行計画のW4(実機能接続)/W5(カットオーバー)、未着手画面(録音モーダル、生成進捗、オンボーディング/ログイン/Paywall — RN未実装)、Settings IA判断から再開できる。

## 主要パス

- RNアプリ: `apps/mobile-expo`
- RN画面: `apps/mobile-expo/src/screens`
- RN共通コンポーネント: `apps/mobile-expo/src/components`
- RNデザイントークン: `apps/mobile-expo/src/design/tokens.ts`
- RNネイティブブリッジ: `apps/mobile-expo/modules/memora-native`
- RN iOS host: `apps/mobile-expo/ios/MemoraRN`
- RN host tests: `apps/mobile-expo/ios/MemoraRNTests`
- 共有Swift package: `Packages/MemoraSharedData`
- SwiftUI V6の参照: `Memora/Views/V6`
- 移行計画と累積ログ: `docs/react-native-expo-migration-plan.md`

## 直近の残タスク

### 1. File Detailヘッダー二重表示の修正 — 完了(2026-07-10)

`apps/mobile-expo/app/_layout.tsx` の `file/[id]` ルートに `headerShown: false` を追加して修正済み。シミュレータのスクリーンショットで、ヘッダーが1つだけになったこと・戻るボタンが正常動作することを確認済み。詳細は移行計画ドキュメントの該当エントリを参照。

### 2. 実機/シミュレータUI確認の残り

Home/File Detail/Ask AI/Settingsの主要導線は2026-07-10にシミュレータで目視確認済み(スクリーンショット証拠あり、詳細は移行計画ドキュメント参照)。未確認のものは以下。

- File Detail: 共有シート、名前変更、要約再生成の実際の動作(表示のみ確認、操作未確認)
- Ask AI: 質問送信〜回答表示〜引用チップの実際のフロー(スコープ切り替えのみ確認)
- Settings: `Omi preview`より下の内容(スクロールジェスチャーの自動化が未解決)
- Home: 録音開始/停止、取り込み、ファイル一覧更新の実際の動作

画面を直接確認できない場合は、確認できなかったことを明記し、推測で「確認済み」と報告しない。

### 3. V6との視覚差分調整

- Homeの`全ファイル`タイトル周辺、フィルター、ファイル行、下部FABの距離を調整。
- File Detailのヘッダー、下線タブ、質問バーの余白を調整。
- Ask AIのscopeタブ、メッセージ最大幅、入力欄のキーボード時挙動を調整。
- Settingsのセクション行、Switch、Bridge診断の密度を調整。
- 既存のSwiftUI V6トークンは `Memora/Views/V6/V6DesignTokens.swift` を参照する。

### 4. ネイティブ境界

- RNの共有/エクスポートは既存のネイティブ契約を確認してから接続する。
- SwiftData共有はまだ有効化しない。App Group、store移行、バックアップ、ロールバックの判断が未完了。
- `configureSharedAudioStore(...)` は検証済みSwiftData storeを明示的に渡すまで既定経路へ接続しない。

## 検証コマンド

RN:

```bash
cd apps/mobile-expo
npm run typecheck
npx expo export --platform web
```

RN iOS host:

```bash
xcodebuild -workspace apps/mobile-expo/ios/MemoraRN.xcworkspace \
  -scheme MemoraRN \
  -destination 'generic/platform=iOS Simulator' \
  build-for-testing
```

共有Swift package:

```bash
cd Packages/MemoraSharedData
swift test
```

差分:

```bash
git diff --check
```

注意: `apps/mobile-expo/package.json` にlint scriptは存在しないため、`npm run lint`は失敗する。これは未修正の既知状態。

## 保護ファイル

明示的な許可なしに以下を変更しない。

- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/STTSupportTypes.swift`
- `Memora/Core/Services/SpeakerDiarizationService.swift`
- `Memora/Core/Services/SpeakerProfileStore.swift`
- `Memora/Core/Services/TranscriptionEngine.swift`
- `Memora/Core/Networking/AIService.swift`
- `Memora/Core/Contracts/CoreDTOs.swift`

バックエンドも今回のRN移行では変更しない。既存のユーザー変更をrevertしない。

## 実装ルール

- 編集前に短く `やること / 変更するファイル / 変更しないファイル` を宣言する。
- 既存パターンを優先し、大規模な抽象化を追加しない。
- 独立した検証は可能な限り並列実行する。
- 各セッションの最後に `docs/react-native-expo-migration-plan.md` のProgressとHandoff Logを更新する。
- 変更後は最低でもtypecheckとgit diff checkを実行する。
- UI変更では、SwiftUI V6との違いを正直に記録する。画面キャプチャを取得していない場合は、視覚確認済みと書かない。

## 作業開始時の指示

1. `docs/react-native-expo-migration-plan.md` とこのファイルを読む。
2. `git status --short` と直近のRN差分を確認する。
3. 実機接続状態とMetroポートを確認する。
4. 実機UI確認と視覚差分修正を優先する。
5. 可能な独立検証は並行して実行する。
6. 作業終了時にこのファイルと移行計画の進捗を更新する。

## 次回セッションの終了条件

- 実機で主要4画面の操作結果を記録している。
- FAB/tab bar/Safe Areaの重なりを確認している。
- typecheck、RN build-for-testing、shared swift test、diff checkの結果を記録している。
- 残タスクと未確認項目を明確にしている。
