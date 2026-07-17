# Memora 開発運用ガイド（2026-07 改訂 / worktree並列開発版）

## 0. 目的
- SwiftUI本番アプリを安定させつつ、`apps/mobile-expo` のRN移行を並行して進める。
- **worktree × 複数セッション**（Claude Code / Codex）を並列開発の標準とする。
- 1セッションの儀式コストを下げ、PRの回転速度を上げる。

## 1. コミュニケーションルール
- 回答・進捗報告・完了報告は日本語。ログ・エラー原文は英語のまま引用可。
- 実装前に「やること / 変更するファイル / 変更しないファイル」を1回だけ短く宣言する。
- 変更は最小差分。依頼範囲外のついでリファクタはしない。
- 証拠なしの「動作したはず」報告は禁止。実行したコマンドと結果を書く。目視できなかったものは「未確認」と明記する。

## 2. 技術前提とディレクトリ責務
- iOS target 17.0 / Xcode 26.x / SwiftUI + SwiftData + MVVM。
- RN側: Expo SDK 57 / React Native 0.86 / TypeScript。

| パス | 責務 |
|---|---|
| `Memora/App` | 起動・ライフサイクル・ModelContainer |
| `Memora/Core/Services` | 録音・再生・STT・要約などドメインサービス |
| `Memora/Core/Models` | SwiftDataモデル |
| `Memora/Core/ViewModels` | 画面状態管理 |
| `Memora/Core/Adapters` | 共有ストア⇔リポジトリのアダプタ |
| `Memora/Views` | SwiftUI UI |
| `Packages/MemoraSharedData` | SwiftUI/RN共有のストア契約・移行ロジック |
| `apps/mobile-expo/src` `app` | RN画面・コンポーネント・デザイントークン |
| `apps/mobile-expo/modules/memora-native` | Expoネイティブモジュール（ブリッジ） |
| `apps/mobile-expo/ios` | RN iOSホスト（**Git管理下。`expo prebuild --clean` 禁止**） |
| `bot-server` | 会議Bot Node/TSサービス |
| `docs` | 計画・決定記録 |

## 3. 並列開発の運用（worktree × セッション）

### 3.1 基本形
- **1セッション = 1レーン = 1 worktree**。worktreeは `../Memora-<slug>` に作る。
```bash
git worktree add ../Memora-<slug> -b <type>/<slug> origin/main
```
- **1 PR = 1目的は維持**。ただし **1セッションで同一レーン内の小PRを連続して複数出してよい**（PRを小さく保ったままセッションを使い切る）。
- セッション開始時に担当レーンを宣言し、他レーンのファイルは触らない。

### 3.2 レーン定義
| Lane | 対象 | 備考 |
|---|---|---|
| A: SwiftUI UI | `Memora/Views/**` | |
| B: 音声/STT | `Memora/Core/Services/Audio*`, `STT*`, `TranscriptionEngine.swift` | §8の保護ルール適用 |
| C: モデル/状態 | `Memora/Core/Models/**`, `ViewModels/**`, `Contracts/**`, `Adapters/**` | |
| D: 基盤/統合 | `Memora/App/**`, `project.yml`, `*.xcodeproj`, `.github/**`, entitlements, Info.plist | **pbxproj/CIはLane Dのみ** |
| E: QA/運用 | テスト、CI結果確認、リリースノート | |
| F: RN UI | `apps/mobile-expo/src/**`, `app/**` | |
| G: RNネイティブ | `apps/mobile-expo/modules/**`, `apps/mobile-expo/ios/**` | ビルドは分離DerivedData（`qa:ios:build`） |
| H: 共有データ | `Packages/MemoraSharedData/Sources/MemoraSharedSchema/**`（**スキーマ/ストア契約のみ**） | C/Gと跨ぐ場合は基盤PR→機能PRに分割。**スキーマ変更は同時に1本だけ** |
| I: Botサーバー | `bot-server/**` | |

- 複数レーンが必要な作業は「基盤PR → 機能PR」の順に分割する。
- 同じレーンを2セッションに同時に割り当てない。

### 共有パッケージの帰属（2026-07の移設後）
`Packages/MemoraSharedData/Sources/` 配下は**ターゲットごとに担当レーンが違う**。Lane H に全部集めると多重占有で並列度が死ぬため、次のとおり分割する。

| ターゲット | 中身 | 担当レーン |
|---|---|---|
| `MemoraSharedSchema` | SwiftDataモデル・スキーマ・移行 | **H** |
| `MemoraSharedCore` | STT実行系・契約・AudioChunker | **B**（STTは§8適用） |
| `MemoraSharedSummary` | 要約エンジン・AIService | **C** |
| `MemoraSharedAskAI` | retrieval・索引 | **C** |

**共有ターゲットを新設したら**、`Package.swift` の library 公開 **と** RNホスト `apps/mobile-expo/ios/MemoraRN.xcodeproj` の `packageProductDependencies` + Sources 登録の**両方**が必要（片方漏れると `no such module`。CIの `rn-ios-build` が検出する）。

### 3.3 レーン別 検証マトリクス（触った範囲だけ検証する）
| 触った範囲 | 必須検証 |
|---|---|
| F（RN UI） | `npm run typecheck` + `npx expo export --platform web` |
| G（RNネイティブ） | 上記 + `npm run qa:ios:build` |
| H（共有データ） | `swift test --package-path Packages/MemoraSharedData` + 影響側のビルド |
| A/C/D（SwiftUI/Core） | `xcodebuild -project Memora.xcodeproj -scheme Memora -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` |
| B（STT） | 上記 + §8の報告義務 |
| I（bot-server） | `npm run build` |
| docsのみ | `git diff --check` のみ |
- 全レーン共通: `git diff --check`。**触っていない範囲の検証は省略してよい**（CIが最終ゲート）。

### 3.4 セッションの型（軽量化）
1. `git fetch origin` → worktree作成（または既存worktreeで `git pull`）
2. レーン宣言 + やること宣言（短く）
3. 実装 → レーン別検証 → コミット → **即push → 即PR作成 → auto-merge設定**
4. 同一レーンで次の小タスクがあれば同セッションで続行（新ブランチを積む）
5. セッション末尾: 完了報告（§6）。**docsへのセッションログ追記は「設計判断があった時だけ」**。進捗の正本はPRとIssueに置く。

## 4. GitHub運用
- `main` への直接push禁止。Squash merge標準。CI green + auto-merge。
- ブランチ命名: `feat|fix|chore/<slug>`（Issueがあれば `<type>/<issue-id>-<slug>`）。
- **ローカルに作ったブランチは当日中にpushしてPRにする**（未pushの巨大checkpointを作らない）。
- マージ済み・不要ブランチは定期的に掃除する:
```bash
git fetch -p && git branch --merged main | grep -v main | xargs git branch -d
git worktree prune
```

## 5. ツール
- **XcodeBuildMCP**: iOSビルド・シミュレータ操作・ログ取得に使用（`doctor` → `build_sim` / `test_sim`、調査時は `start_sim_log_cap`）。
- PM系: Epic分解は `/pm-breakdown`、割当は `/pm-assign`（`docs/pm-agent-workflow.md`）。
- 大きなEpicで必要な場合のみAgent Teams（`docs/agent-teams-playbook.md`）。日常は worktree × セッション を優先する。

## 6. 完了報告テンプレート（軽量版）
- 変更概要（1〜3行）
- 変更ファイル
- 実行した検証（コマンド → pass/fail）
- 未確認事項
- PR URL / 次のタスク

## 7. 禁止事項
- `main` への直接push
- 担当レーン外の無断変更
- 未pushの巨大checkpointコミット（1 PR = 1目的の破壊）
- 証拠なしの完了報告
- 仕様変更をコード先行で進めること
- `apps/mobile-expo` での `expo prebuild --clean`（手書きiOSホストが消える）

## 8. 文字起こしコア保護ルール
文字起こしはMemoraのコア機能。詳細は `docs/transcription-core-boundary.md`。
明示依頼がない限り、次のファイルは編集しない:
**共有パッケージ側**（2026-07の移設で移動。旧パスは存在しない）:
- `Packages/MemoraSharedData/Sources/MemoraSharedCore/STTService.swift`
- `Packages/MemoraSharedData/Sources/MemoraSharedCore/CoreDTOs.swift`
- `Packages/MemoraSharedData/Sources/MemoraSharedSummary/AIService.swift`

**アプリ側**（元の場所のまま）:
- `Memora/Core/Services/STTSupportTypes.swift`
- `Memora/Core/Services/SpeakerDiarizationService.swift`
- `Memora/Core/Services/SpeakerProfileStore.swift`
- `Memora/Core/Services/TranscriptionEngine.swift`

STTコアを変更する場合は必ず報告する: バックエンド選択順の変更点 / SpeechAnalyzer・SFSpeechRecognizer・APIのどこに影響するか / 話者分離と保存フォーマットへの影響 / build・test・logの確認結果。

## 9. デザイントークン（黄金比）
- 比率 `phi = 1.618` / Spacing `5, 8, 13, 21, 34, 55` / Radius `8, 13, 21` / Type `12, 14, 17, 21, 26, 34` / 行間 `×1.45〜1.62`
- RN側の正本は `apps/mobile-expo/src/design/tokens.ts`（旧V6トークン名は廃止済み。復活させない）。
- UIレビュー合格条件: 余白がスケールに乗る / 最小タップ領域44pt / 視覚重心が崩れない。

## 10. ドキュメントの正本順序
矛盾したら上を優先する。
1. `docs/Memora_Product_North_Star.md` — プロダクト方針
2. `docs/Memora_vNext_Current_Truth_and_Execution_Plan.md` — SwiftUI側の現在地
3. `docs/react-native-expo-migration-plan.md` — RN移行の現在地（ログは肥大化させず、判断だけ記録）
4. 各決定記録（`react-native-swiftdata-target-sharing-decision.md`, `app-store-review-readiness.md`, `online-meeting-capture-plan.md`）
