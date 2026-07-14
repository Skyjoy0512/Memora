# App Store 審査通過のための実装計画

Last updated: 2026-07-13
対象: SwiftUI 本番アプリ（`Memora/**`）。React Native/Expo版(`apps/mobile-expo`)は審査提出対象外。
発行元: Claude Code レビューセッション（現行コードを確認済み、コード未変更）

> この文書は「審査に落ちる要因」と「その解決策」を実装計画として定義する。
> 各ブロッカーには対象ファイル・解決策・推奨アプローチを付す。
> ⚠️非コード作業（App Store Connect側の設定）は末尾の§4に分離。

## 0. 現状で確認された審査ブロッカー（コードで確認済みの事実）

| # | 事象 | 該当箇所 | 抵触ガイドライン |
|---|---|---|---|
| B1 | **偽のサインイン**: 「Apple でサインイン」「Google で続ける」「メールで続ける」ボタンが実際には認証せず `authStageRaw` を paywall に進めるだけ | `Memora/Views/Auth/V6AuthFlowView.swift:141-149` | 2.3.1(誤解を招く), 4.8(第三者ログイン時はSign in with Apple必須) |
| B2 | **偽のペイウォール**: StoreKit不使用。「7日間無料で試す」が `isPro = true` にするだけ。存在しない機能(月1200分・クラウド保存)を宣伝 | `V6AuthFlowView.swift:319`, `Memora/Views/V6/V6AppShellView.swift:1599` | 3.1.1(デジタル課金はIAP必須), 2.3.1 |
| B3 | **Privacy Manifest欠如**: SwiftUIアプリに `PrivacyInfo.xcprivacy` が無い（RN版には有るがそれは別バンドル） | `Memora/` 配下に無し | 2024以降 privacy manifest 必須 |
| B4 | **バックグラウンド録音の申告欠如**: `UIBackgroundModes: audio` が Info.plist に無い。V6は「最小化して録音継続」を売りにしている | `Memora/Resources/Info.plist`（NSSupportsLiveActivitiesのみ） | 2.3.1(機能主張と実態の不一致) ※§1-B4で条件付き |
| B5 | **機能しないUI**: Dynamic Islandのデモ問答固定文、動かない通知トグル、無反応の設定行など（別レビューで既出） | 前回UIレビュー参照 | 2.3.1 |
| B6 | **暗号化コンプライアンス未申告**: `ITSAppUsesNonExemptEncryption` が Info.plist に無い | `Memora/Resources/Info.plist` | 提出時に毎回聞かれる（設定で省略可） |

## 0.1 実装済みの提出準備（2026-07-13）

- B3: `Memora/Resources/PrivacyInfo.xcprivacy` を追加し、アプリターゲットのResourcesへ登録した。追跡なし、UserDefaults（`CA92.1`）とファイル時刻（`C617.1`）の利用理由、外部AI／Files送信で扱いうる音声・ユーザー作成コンテンツをアプリ機能目的として申告している。
- B6: `ITSAppUsesNonExemptEncryption = false` を追加した。標準暗号のみを利用する現状の申告であり、独自暗号または非免除の暗号化機能を将来追加する場合は再判定する。
- 確認済み: Xcodegen再生成後のSimulator buildで、両方が生成済みの`Memora.app`に含まれることを確認した。

提出直前には、最終的なAIプロバイダー・外部送信・SDK構成とApp Store ConnectのApp PrivacyラベルをこのManifestと再照合する。

## 1. 実装タスク（コード側）

### 方針の大前提

North Star (`docs/Memora_Product_North_Star.md` §4) は **サインイン・ペイウォール・オンボーディング大型刷新を明確に「後回し(P4)」** と定義している。
したがって **B1/B2 は「実装」ではなく「初回リリースビルドから除去(スキップ)」が正解**。
StoreKit + Sign in with Apple + アカウント削除をフル実装するのは、収益化を今出す明確な意思がある場合のみ（§1-B1代替案）。

---

### B1+B2: 認証・ペイウォールを初回リリースから除去（推奨・最優先）

**やること**:
- アプリ起動時の初期認証ステージを実質スキップする。`V6AuthStage` の初期値を `.done` にし、
  未認証フロー(`onboarding`/`login`/`paywall`)を**リリースビルドで表示しない**。
  - `Memora/App/ContentView.swift:15` の `@AppStorage(V6AuthStorageKey.stage) private var v6AuthStageRaw = V6AuthStage.onboarding.rawValue`
    を `.done.rawValue` に。または `#if DEBUG` 時のみオンボーディングを見せる分岐にする。
- 設定画面(`V6AppShellView.swift`)の「プラン」バッジ行・ペイウォール導線(`showPaywall`)、
  「Proでクラウド」等の未実装機能を指す文言を除去または非表示。
- `V6PaywallSheet`・`V6AuthFlowView` のコードは削除せず残してよいが、**リリースビルドの到達経路をゼロにする**。
- 「Free/Pro」概念に依存した表示分岐（添付の保存先「この端末（Proでクラウド）」等）を、
  Proを前提にしない中立な文言へ。

**受け入れ条件**: リリースビルドでアプリ起動→いきなりホーム。サインイン画面・課金画面に一切到達できない。
「Pro」「無料トライアル」「月1200分」等の未実装機能の宣伝文言が残っていない。

**代替案（収益化を今出す場合のみ・非推奨）**: StoreKit 2で実課金、Sign in with Apple実装(ASAuthorization)、
アカウント削除機能(5.1.1(v))、復元(Restore)ボタン、価格・利用規約・プライバシーの表示を全て実装。
工数大。North Star方針に反するため初回では避ける。

---

### B3: Privacy Manifest の追加

**やること**:
- `Memora/Resources/PrivacyInfo.xcprivacy` を新規作成し、アプリターゲットにバンドル
  （pbxproj登録が必要 = Lane D）。
- 申告内容（実コードの使用状況に合わせる。過不足は審査で指摘される）:
  - `NSPrivacyTracking`: false（トラッキングしていないなら）
  - `NSPrivacyCollectedDataTypes`: 音声データ、ユーザーコンテンツ（録音・文字起こし）。
    外部AIプロバイダ(OpenAI/Gemini/DeepSeek)へ送信する場合は該当データ型を「App機能のため」で申告。
  - `NSPrivacyAccessedAPITypes`: 使用しているrequired-reason API を列挙
    （UserDefaults[CA92.1]、File timestamp[C617.1] ← §device-integration の createdAt読み取りで使用 等）。
    実際に使っているAPIのみ。Xcodeのビルド警告で不足を検出できる。

**受け入れ条件**: アーカイブ時にprivacy manifest関連の警告が出ない。

---

### B4: バックグラウンド録音（条件付き）

**まず判定**: 「最小化して録音継続」が **アプリをバックグラウンド/画面ロックに送っても録音が続く**仕様か、
**アプリは前面のまま録音モーダルを閉じるだけ**か、を実コードで確認する
（`V6RecordingSessionController` はモーダル破棄後も録音を保持するが、これはフォアグラウンド内の話の可能性）。

- **バックグラウンド録音を出荷するなら**:
  - `Info.plist` に `UIBackgroundModes: [audio]` を追加。
  - `AVAudioSession` を `.record`/`.playAndRecord` + バックグラウンド継続可能な構成にする
    （STTコア §10 に触れない範囲で、録音セッション設定側のみ）。
  - App Privacy / レビューノートでバックグラウンド録音の目的を説明。
- **出荷しないなら**:
  - UI文言から「最小化しても録音が続く」印象を与える表現を除去し、`UIBackgroundModes` は追加しない。

**受け入れ条件**: 実機で画面ロック中の録音挙動が、UIの主張と一致する。

---

### B5: 機能しないUIの排除

別レビューの成果物（Dynamic Islandデモ問答、通知トグル、無反応設定行など）を審査前に潰す。
SwiftUI側の該当は前回のUIレビュー指摘（偽Ask問答 `V6DynamicIslandPill.swift:146`、
無反応の設定chevron行、@AppStorageのみの通知トグル等）を参照。実データに繋がらない操作は
「準備中」表示 or 非表示にする（`docs/rn-expo-ui-polish-handoff.md` のバッチA方式と同じ思想）。

**受け入れ条件**: 押せるUIは全て実際に何かが起きる。デモ固定文が本番導線に出ない。

---

### B6: 暗号化コンプライアンス申告

- `Info.plist` に `ITSAppUsesNonExemptEncryption` を追加。
  HTTPS/標準暗号のみの利用なら `false`。独自暗号を使わない限りこれで提出時の質問を省略できる。

**受け入れ条件**: App Store Connect提出時に暗号化の質問が出ない。

---

## 2. 実装順序と Lane

| 順 | 項目 | Lane | pbxproj | 備考 |
|---|---|---|---|---|
| 1 | B6 暗号化申告 + B4判定/対応 | D | 一部 | Info.plist編集。小さい |
| 2 | B1+B2 認証・課金の除去 | A(Views)+D | 無 | 初期ステージ変更 + 導線除去 |
| 3 | B5 機能しないUI排除 | A | 無 | 前回UIレビュー成果物 |
| 4 | B3 Privacy Manifest追加 | D | 有 | 新規ファイル登録 |

- pbxprojを触るのは Lane D のPRのみ（CLAUDE.md §5.2）。
- STTコア(§10)には一切触れない。B4のAVAudioSession設定は録音セッション構成側に限定。

## 3. 検証

```
xcodebuild archive -project Memora.xcodeproj -scheme Memora \
  -destination 'generic/platform=iOS' -configuration Release
```
- アーカイブが privacy manifest / 暗号化の警告なしで通ること。
- リリースビルドで起動→サインイン/課金に到達しないこと（目視）。
- 実機でバックグラウンド録音挙動がUIの主張と一致すること（目視）。

## 4. ⚠️ 非コード作業（App Store Connect / 提出者が行う）

コードだけでは審査を通せない。以下は人間が App Store Connect と外部で用意する。

| # | 項目 | 内容 |
|---|---|---|
| C1 | **プライバシーポリシーURL** | 会話録音・外部AI送信を明記した公開ページを用意しURL登録。必須 |
| C2 | **App Privacy 栄養ラベル** | 収集データ型（音声・ユーザーコンテンツ）と用途、第三者(AIプロバイダ)送信を申告。B3のmanifestと整合させる |
| C3 | **レビューノート** | ⚠️最重要: 文字起こし/要約がユーザー持ち込みAPIキー(BYOK)前提だと、レビュアーが試せず 2.1(App Completeness)で落ちる。**既定でローカル文字起こし(SpeechAnalyzer/SFSpeechRecognizer)が動作し、APIキー無しで主要機能を体験できる**旨と手順を明記する。ローカルで完結しない機能があるならデモ用アカウント/キーを提供 |
| C4 | **年齢レーティング** | 質問票に回答 |
| C5 | **輸出コンプライアンス** | B6を`false`で申告済みなら追加作業なし |
| C6 | **スクリーンショット/キーワード** | 「PLAUD」「Limitless」等の商標を機能名として大書しない（互換性の事実記述のみ）。存在しない機能(Pro/クラウド)を写さない |
| C7 | **Sign in with Apple** | B1で認証を除去するなら不要。もし第三者ログインを出すなら4.8対応が必須になる |

## 5. リスクの残る論点（判断が必要）

- **外部AIへの会話送信**: 録音内容を第三者API(OpenAI等)に送るのはプライバシー影響が大きい。
  App Privacyでの正確な申告 + アプリ内での明示的な同意/説明が望ましい（審査だけでなく信頼の観点）。
- **BYOKモデルの是非**: ユーザーが自分のAPIキーを入れる設計は、C3のレビュー体験問題に加え、
  一般ユーザー向けとしてハードルが高い。ローカル文字起こしを既定にする方針を推奨。
- **PLAUD/Limitless連携（`docs/device-integration-plan.md`）**: 非公式API経路は出荷ビルドから
  除外(DEBUG格納)する方針を守れば審査上の第三者サービス無許可アクセス(5.2.2)を回避できる。
