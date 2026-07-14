# 25. Figma(Memora_v0.2)整合 設計追補

対象: Figma `Memora_v0.2`(node 103-10292、PDF: Group_325)に画面遷移・機能を寄せる
前提: Ph2 実装(18ブランチ)のレビュー結果(32 参照)を踏まえた差分定義

---

## 1. Figma の画面フロー(PDF 左→右の読み取り)

```
オンボーディング×4 → サインイン(Apple/Google) → ペイウォール(7日間無料トライアル)
→ Home(PLAUDピル / 検索 / ファイル・プロジェクト切替 / カード一覧 / フローティングタブバー+FAB)
   ├─ FAB展開: 録音開始 / インポート / 会議キャプチャー
   ├─ 録音中: Home上のミニ録音バー(ファイル名+経過時間+Pause/Stop)
   ├─ デバイス詳細(バッテリー80% / デバイス名 / シリアル / FW / ペアリング解除)
   └─ プロジェクト: カードグリッド + プロジェクト作成 + Ask Anything バー
→ ファイル詳細(生成前): タブ[文字起こし|メモ] + Upload image + 生成CTAカード
→ 生成フロー(ボトムシート): 自動生成/カスタム生成 → テンプレート選択 → AIモデル選択 → 生成中
→ ファイル詳細(生成後): タブ[要約|文字起こし|メモ] + 構造化サマリ + Ask Anything バー(モデルチップ GPT-5.2)
→ 文字起こしタブ: SpeakerA/B/C + タイムスタンプ / メモタブ
```

## 2. ギャップ表(Figma vs 現状[main+Ph2ブランチ] vs アクション)

| # | Figma 要素 | 現状 | アクション | 規模 |
|---|---|---|---|---|
| F-1 | フローティングタブバー(Home/ToDo/AskAI/Setting)+中央FAB | 標準 TabView(「UI統合」で戻した)。旧実装が git 履歴に存在(FloatingTab 等) | **要決定 D-1**。復活なら旧コード流用可 | M |
| F-2 | FAB 3項目(録音開始/インポート/会議キャプチャー)、PLAUD はヘッダーピル | Ph2 の feat/home-capture-fab は FAB 4項目(PLAUD同期含む)+toolbar | FAB を3項目に、PLAUD 導線をヘッダーピルへ移動 | S |
| F-3 | ファイル詳細タブ: 生成前[文字起こし\|メモ]→生成後[要約\|文字起こし\|メモ](動的) | Ph2 の fix/filedetail-fixed-tabs は**常時3固定**(設計01) | **要決定 D-2**(Figma準拠なら A2 を改修) | S |
| F-4 | 生成フロー: ボトムシート(自動/カスタム→テンプレ横カード→モデルリスト) | refactor/generation-flow-sheet(NavigationStack sheet)が機能的に一致 | ビジュアルのみ Figma 寄せ(detent/カードUI)。構造は流用 | S-M |
| F-5 | AIモデル: ChatGPT-5/Thinking/mini/4o + **Claude Opus4.6** + Gemini 3.1-Pro Beta | provider は openai/gemini/deepseek/local。**Anthropic なし** | Anthropic provider 追加(要約・AskAI用)+モデル選択UIをマルチプロバイダ化 | M |
| F-6 | Ask Anything バー(モデルチップ付き)を Home/プロジェクト/ファイル詳細に常設 | FileDetail の AskAICompactBar のみ | グローバル Ask バー化 + モデル切替チップ | M |
| F-7 | 録音 = Home 上のミニバー(Pause/Stop) | フルスクリーン RecordingView push | ミニ録音バー新設(RecordingView は詳細表示として残す) | M |
| F-8 | Upload image(ファイル詳細ヘッダー) | なし | カバー画像添付機能(AudioFile に imagePath 追加) | S-M |
| F-9 | デバイス詳細: バッテリー/シリアル/FW/ペアリング解除 | DeviceDetailView 実装済(項目差分あり) | 項目とレイアウトを Figma に合わせる | S |
| F-10 | オンボーディング×4 + Apple/Google サインイン + ペイウォール(7日トライアル) | なし | **要決定 D-3**(新スコープ: 認証+課金) | L |
| F-11 | 文字起こし: Speaker ラベル+タイムスタンプ表示 | 設計03(タイムスタンプ)/06(話者分離)で計画済み・未実装 | 既存計画どおり(03/06 を Ph3 で) | 計画済 |

## 3. 要決定事項(実装前にユーザー判断)

**D-1: タブバーを Figma のフローティング型に戻すか**
- Figma 準拠 = カスタムフローティングタブバー+中央FAB。旧実装(5月)が履歴にあり流用可能。
- 一方「UI統合」で標準 TabView に戻した経緯がある(Claude Design 再現が不調だった件とは別問題)。
- 推奨: **Figma 準拠で復活**。ただし旧コードの丸ごと復元でなく、標準 TabView の上に overlay する軽量実装に作り直す(タブ切替は TabView に委譲し、見た目だけカスタム)。アクセシビリティと iOS 26 glassEffect 対応を維持。

**D-2: ファイル詳細タブは動的(Figma)か常時3固定(設計01)か**
- 設計01 は「タブ増減は空間記憶を壊す」として常時3固定にした(Ph2 で実装済み)。
- Figma は生成前2タブ→生成後3タブの動的。
- 推奨: **Figma 準拠(動的)に変更**。ただし設計01が問題視した「選択中タブの強制付け替え」は起こさない実装にする(要約タブは末尾に追加されるだけで、選択中タブは維持)。fix/filedetail-fixed-tabs は availableTabs の返却を Figma 仕様に修正してからマージ。

**D-3: オンボーディング/認証/ペイウォールのスコープ**
- Sign in with Apple/Google は認証バックエンド(Firebase Auth 等)が必要。ペイウォールは StoreKit 2 サブスク実装+審査要件(復元ボタン等)。合わせて L サイズの新トラック。
- 推奨フェーズ分割: ①オンボーディング4画面(静的・ローカル完結)だけ先行、②ペイウォール(StoreKit 2)、③認証は**クラウド同期(23)を実装するときに一緒に**(それまでアカウント不要のローカルアプリなので認証の必然性が薄い)。

## 4. Figma 寄せの PR 分割(Ph3-UI として)

| PR | 内容 | 依存 |
|---|---|---|
| PR-F1 | FAB 3項目化 + PLAUD ヘッダーピル(F-2) | feat/home-capture-fab マージ後 |
| PR-F2 | フローティングタブバー復活(D-1 承認後)(F-1) | PR-F1 |
| PR-F3 | ファイル詳細タブ動的化(D-2 承認後)(F-3) | fix/filedetail-fixed-tabs の改修 |
| PR-F4 | 生成シートのビジュアル Figma 寄せ(F-4) | refactor/generation-flow-sheet マージ後 |
| PR-F5 | Anthropic provider + モデル選択マルチプロバイダ化(F-5) | なし(コア: AIService 追加) |
| PR-F6 | Ask Anything グローバルバー+モデルチップ(F-6) | PR-F5 |
| PR-F7 | 録音ミニバー(F-7) | PR-F2 |
| PR-F8 | カバー画像 Upload(F-8) | なし |
| PR-F9 | デバイス詳細 Figma 整合(F-9) | なし |
| PR-F10 | オンボーディング4画面(D-3①) | なし |
| PR-F11 | ペイウォール StoreKit 2(D-3②) | PR-F10 |

推奨順: F1 → F3 → F4 → F5 → F6 → F2 → F7 → F9 → F8 → F10 → F11

## 5. 実装エージェントへの注意

- Figma の視覚仕様(色/余白/角丸)は Figma 側が正。既存 MemoraColor/MemoraSpacing に無い値は DesignSystem にトークン追加してから使う(直値散布禁止)。
- 「GPT-5.2」「Claude Opus4.6」「Gemini 3.1-Pro」等のモデル名はハードコードせず、設定可能なモデル定義(id/displayName/provider/badge)テーブルにする。モデル改廃が頻繁なため。
- F-10 の認証はネットワーク・個人情報を扱う。実装時は Sign in with Apple の審査ガイドライン(Google サインインを載せるなら Apple も必須)に従う。
