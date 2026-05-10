# Memora UI Reproduction Spec for ClaudeCode

この設計書は、Figma/添付スクリーンショットのUIをSwiftUIで差分なく再現するための実装指示書です。ClaudeCodeは「既存画面をそれっぽく整える」のではなく、スクリーンショット一致をゴールにして実装してください。

## ゴール

- 対象画面を添付スクリーンショットと可能な限り一致させる。
- iOS 26のLiquid Glassを使う箇所は、`glassEffect` / `GlassEffectContainer` を使って実装する。
- iOS 17-25では既存の `.ultraThinMaterial` 系フォールバックで破綻しないようにする。
- 既存のデータ取得、ファイル詳細遷移、録音、インポート、会議キャプチャ、文字起こし、要約生成、Ask AIの機能は維持する。
- 標準NavigationBar/List/TabViewの自動余白でスクショからズレる場合は、カスタムレイアウトを優先する。

## 対象ファイル候補

- `Memora/Views/HomeView.swift`
- `Memora/App/ContentView.swift`
- `Memora/Views/DeviceDetailView.swift`
- `Memora/Views/FileDetail/FileDetailView.swift`
- `Memora/Views/FileDetail/FileDetailHeader.swift`
- `Memora/Views/FileDetail/SummaryTab.swift`
- `Memora/Views/FileDetail/TranscriptTab.swift`
- `Memora/Views/FileDetail/MemoTab.swift`
- `Memora/Views/FileDetail/PlayerControls.swift`
- 必要なら `Memora/DesignSystem/Components/` に小さな再利用コンポーネントを追加

## 全体デザイン原則

- 背景色は薄いグレー。基準は `#ECECEC`。
- 主要カードは白 `#FFFFFF`。
- 補助面は `#F3F3F3` から `#F4F4F4`。
- 検索バー/選択ピルは `#DDDDDE` / `#D9D9D9`。
- 文字色は本文黒、補助テキストは `#58585A`、プレースホルダーは `rgba(60,60,67,0.6)` 相当。
- 角丸は大きめ。カードは16-28pt、ピルは高さの半分。
- 画面はiPhone縦長を基準にする。左右基本余白は32-34ptではなく、スクショ上は左右約33pt、Figma上は16.5pt指定の内側レイアウトとして扱う。
- SF Pro前提。SwiftUIでは `.system(size:weight:)` を明示して標準タイトルスタイルに任せない。
- 文字の負のletter spacingは使わない方針だが、Figmaの微細な詰まりは必要最小限で `.tracking(-0.1...-0.4)` を使ってよい。

## Liquid Glass方針

Liquid Glass対象:

- ホーム上部 `PLAUD Note Pro` ボタン
- ホーム右上 `AA` ボタン
- ホームFAB `+` / `x`
- FAB展開メニューの各アクションピル
- 下部タブバー
- プロジェクト作成ボタン
- Ask Anything入力バー
- デバイス詳細の戻るボタン
- ファイル詳細の戻る/再生/共有/三点ボタン
- 生成オプション、テンプレート選択、AIモデル選択のボトムシート
- 録音中ボトムシート

実装ルール:

- iOS 26:
  - 近接する複数のガラス要素は `GlassEffectContainer` で囲う。
  - タップ可能なボタンは `.glassEffect(.regular.interactive(), in: shape)`。
  - 丸ボタンは `.circle` または `.rect(cornerRadius: size / 2)`。
  - ピルは `.rect(cornerRadius: height / 2)`。
- iOS 17-25:
  - `.ultraThinMaterial` + 白の薄いoverlay + 0.5pt白stroke + shadow。
- ガラス面に濃い塗りを重ねすぎない。スクショでは白く発光した半透明面に見える。

## Home

### 通常ファイル一覧

画面構造:

1. 背景
2. iOSステータスバー領域
3. 上部デバイス/設定行
4. 検索バー
5. ファイル/プロジェクト切替
6. ファイルカードリスト
7. 右下FAB
8. 下部Liquid Glassタブバー

上部:

- 左: `PLAUD Note Pro`
  - タップでデバイス詳細画面へ遷移。
  - 幅はテキスト+左右40pt程度、高さ43pt。
  - 左端は画面左から約33pt。
  - Liquid Glassピル。
  - テキスト: 13-17pt相当。スクショではやや大きく見えるため、実機スクショで調整。
- 右: `AA`
  - 直径約56pt外側、内側グレー円は約44pt。
  - 外側はLiquid Glass、内側は `#B2B2B2`、文字は白。

検索バー:

- 左右余白約33pt。
- 高さ約80px相当、実装上は40-44ptではなくスクショ基準でやや厚く見せる。iPhone実機では44-50ptを目安。
- 背景 `#DDDDDE`。
- 角丸は高さの半分。
- 左に虫眼鏡アイコン、続いて `Search`。
- プレースホルダーはグレー、大きめ。

ファイル/プロジェクト切替:

- セグメント全体の背景は持たない。
- 選択中だけ `#D9D9D9` のピル背景。
- `ファイル` 選択時:
  - `ファイル` ピル、`プロジェクト` はテキストのみ。
- `プロジェクト` 選択時:
  - `プロジェクト` ピル、`ファイル` はテキストのみ。
- 左寄せ。検索バー下に約40pt以内。

ファイルカード:

- 左右余白約33pt。
- カード背景白。
- 角丸約24pt。
- カード間隔約20pt弱。
- 1枚目は要約あり:
  - 高さ約240px相当。
  - 左に丸いアイコン背景 `#F3F3F3`、直径約88px相当。
  - タイトル `2025-01-24_エンジニア定例` は太字、黒、1行省略。
  - 日付行は `2025/12/12, 56min`、補助グレー。
  - 右上三点メニューは横三点、濃いグレー。
  - 下に要約プレビュー背景 `#F4F4F4`、角丸12-16pt。
  - 要約テキストは2行まで。
- 通常カード:
  - 高さ約130px相当。
  - 内容はアイコン、タイトル、日付、三点のみ。
- 処理中カード:
  - タイトルは `#C8C8C8`。
  - アイコンはアップロード/処理を示す。
  - 黒い進捗バー + 薄グレーのトラック。
  - `処理中` を小さく表示。

FAB:

- 通常は右下に白いLiquid Glass丸ボタン。
- 直径約72px相当。
- 下部タブバーより上、右端から約32pt。
- 展開時は `+` が `x` になる。
- 展開メニュー:
  - 右寄せ縦並び。
  - `録音開始` / `インポート` / `会議キャプチャ`
  - 各行は白いLiquid Glassピル、幅約330px相当、高さ約80px相当。
  - FABの真上に3つ積む。

下部タブバー:

- 画面下に浮いたLiquid Glassピル。
- 左右余白約40pt、下余白約34pt。
- 高さ約96px相当。
- タブは4つ: `Home`, `ToDo`, `Setting`, `AskAI`。
- Home選択時は左タブにグレーの丸角選択背景。
- アイコンはSF Symbolsで近似:
  - Home: `house`
  - ToDo: `checkmark.circle`
  - Setting: `gearshape`
  - AskAI: 既存のsparkle/rosette系。スクショでは黒い花形アイコンに見えるため可能ならカスタムまたはSF Symbol近似。

### プロジェクトタブ状態

- 同じ上部/検索/切替。
- `プロジェクト` ピルが選択。
- コンテンツは2カラムカード。
- カード:
  - 白背景、角丸約24pt。
  - 幅は左右2枚で等分。左右余白約33pt、カード間約16pt。
  - 上部左に小アイコン円、右に三点。
  - タイトル `Project Title` 太字。
  - サブ `4 Files` グレー。
  - 高さは約350px相当。
- 右下付近に `+ プロジェクト作成` Liquid Glassピル。
- 下部にAsk Anything入力バーが表示される。

### Ask Anything入力バー

- 白いLiquid Glass大きめカード。
- ホームのプロジェクト状態と詳細画面で使用。
- 左上に `Ask Anything` placeholder。
- 左下にクリップアイコン。
- 右下にモデル名 `GPT-5.2` とchevron、さらに黒丸の音声/送信ボタン。
- 画面下部タブバーの上に浮く。
- 詳細画面では本文に重なる。重なる前提で下部paddingを十分取るか、スクショ一致を優先してoverlay固定。

## Device Detail

遷移元: ホーム左上 `PLAUD Note Pro` ピル。

画面:

- 背景 `#ECECEC`。
- 左上にLiquid Glass丸戻るボタン。
  - 直径約96px相当、実装上56-64pt。
  - 中にchevron-left。
- 大タイトル `PlaudNote Pro`
  - 左寄せ。
  - 太字、非常に大きい。SwiftUIでは36-44pt目安。
- 中央にPLAUDデバイス画像。
  - 実装には画像アセットが必要。Figmaまたはユーザー提供画像をAssetsに入れる。
  - 画像は幅約340px相当、中央配置。
- 画像下にバッテリー表示:
  - バッテリーアイコン + `80%`
  - 太字。
- ページインジケータ:
  - 3点。
  - 1点目黒、残りグレー。
- 情報カード:
  - 白背景、角丸約24pt。
  - 左右余白約48px相当。
  - 3行、高さ各約88px相当。
  - `デバイス名` / `PLAUD_NOTE_Ken`
  - `シリアル番号` / `123456789`
  - `ファームウェアバージョン` / `v 0.01`
  - 行区切り線は薄いグレー。
  - 左ラベル、右値。右値は右寄せ。
- 下部解除ボタン:
  - 赤 `#FF3030` 系。
  - 白文字 `ペアリングを解除`。
  - 太字。
  - 横幅ほぼ全体、左右約48px相当。
  - 高さ約96px相当、ピル角丸。
  - 影あり。

## File Detail / Generate Before

遷移元: ホームの音声ファイルカード。

画面共通:

- 背景 `#ECECEC`。
- 標準NavigationBarは使わず、カスタムトップバー。
- 上部余白はステータスバーを考慮。スクショではコンテンツ開始がかなり上。
- 上部ボタン:
  - 左: 戻るLiquid Glass丸ボタン。
  - 中央: 再生Liquid Glassピル/丸角ボタン。中にplay三角。
  - 右側: 共有Liquid Glass丸ボタン、三点Liquid Glass丸ボタン。
  - 3つは上端に横並び。戻るは左、再生は中央、共有/三点は右。
- タブ:
  - `文字起こし`, `メモ` または生成後は `要約`, `文字起こし`, `メモ`。
  - 選択中のみグレーのピル背景。
  - 非選択はテキストのみ。
  - 左寄せ気味。

生成前画面:

- タイトル `2025-01-24.mp3`
  - 大きい太字、左寄せ。
- 画像アップロード枠:
  - 左右余白約40px相当。
  - 高さ約150px相当。
  - 背景は透明または薄いグレー。
  - 白stroke 2pt相当。
  - 角丸約28pt。
  - 中央に画像アイコン + `Upload image`。
- 中央の生成イラスト:
  - 点線の同心円3つ。
  - 左丸アイコン: 音声波形。
  - 中央: 右矢印。
  - 右丸アイコン: ドキュメント。
  - 丸は白背景、影あり。
- 説明:
  - 見出し `文字起こし・要約を生成する`
  - 太字、中央寄せ。
  - 下に説明文:
    - `音声の内容を把握し重要ポイント・決定事項・タスクを自動抽出します。`
  - 補助グレー、2行。
- 下部生成ボタン:
  - 黒背景。
  - 白文字 `生成`。
  - 横幅ほぼ全体、左右約58px相当。
  - 高さ約108px相当、実装上64-72pt程度。
  - 角丸大きいピル。
  - 画面下から約44pt。

## Generate Option Bottom Sheets

共通:

- 背景は元画面を暗くディム。スクショではグレーoverlayが強い。
- ボトムシートはLiquid Glass。
- 上端左右角丸大きめ。角丸約36-44pt。
- 白stroke 1pt。
- 上中央にドラッグインジケータ:
  - 幅約72px、高さ8px、角丸、`#A7A7A7`。
- 下部の黒い `生成` ボタンはシート内下部固定。
- ボタンは黒、白文字、太字、影あり。

### 生成方式選択シート

- 高さは画面下から約450px相当。
- 選択肢:
  - `自動生成`
    - 左にsparkleアイコン。
    - サブ: `内容に応じて最適な形に自動要約`
  - `カスタム生成`
    - 左にgrid+アイコン。
    - サブ: `テンプレートを選択して要約`
    - 右にchevron。
- 行間は広め。
- `カスタム生成` タップでテンプレート選択シートへ。

### テンプレート選択シート

- タイトル `テンプレートを選択` 中央、太字。
- 上に横スクロールカード。
- カード:
  - 白背景。
  - 角丸約20pt。
  - 幅約300px相当、高さ約280px相当。
  - タイトル例:
    - `議事録`
    - `詳細な議事録`
  - 説明:
    - `テンプレートの内容説明がここに入ります`
  - 横スクロールで右のカードが途中まで見える。
- 下部行:
  - 左 sparkleアイコン + `AIモデル`
  - 右 `ChatGPT-5` + chevron
- 下部 `生成` ボタン。

### AIモデル選択シート

- タイトル `AIモデルを選択` 中央、太字。
- リスト:
  - `ChatGPT-5` / `OpenAI` / 右チェック
  - `ChatGPT-5 Thinking` / `OpenAI`
  - `ChatGPT-5 mini` / `OpenAI`
  - `ChatGPT-4o` / `OpenAI`
  - `Claude Opus4.6` / `Anthropic`
  - `Gemini-3.1-Pro` / `Google` + `Beta`バッジ
- 左アイコン:
  - OpenAIロゴ、Anthropicロゴ、Geminiロゴが理想。
  - ロゴアセットが無ければSF Symbolで代用せず、簡易ベクター/画像アセットを用意する。
- サブテキストは薄いグレー。
- チェックは右端。
- 下部 `生成` ボタン。

## File Detail / Loading

生成中/読み込み中状態:

- 上部ボタン/タブ/画像アップロード枠は維持。
- タイトル部分はグレーのスケルトンバーになる。
- 本文エリア:
  - 大きな角丸スケルトンカード。
  - 下に複数の横長スケルトンバー。
- 下部に黒い `生成` ボタンは残る。
- スケルトン色は `#D9D9D9` 系。
- アニメーションは必要ならshimmer。ただしスクショ一致を優先し、静的グレーでも可。

## File Detail / Generated Summary

スクショは細長い縦全体。コンテンツはスクロール。

上部:

- ステータスバーの下に小さなトップボタン群。
- 戻る、再生、共有、三点。
- タブは `要約`, `文字起こし`, `メモ`。
- 選択中タブのみ小さなグレーピル。
- 日時 `2021-05 20,09:31 PM` のような小さいメタ情報。
- タイトル:
  - `06-25 AskAI機能 仕様定義・技術要件討議`
  - 2行まで。
  - 太字。

画像エリア:

- 最初に小さいUpload image枠。
- 横スクロールで複数サムネイル。
- その下に大きめのプレビュー画像。
- 画像角丸あり。

要約本文:

- 見出し `サマリー` + 下向きchevron。
- 本文は日本語長文。
- 次に `ノート` + 下向きchevron。
- セクション番号、箇条書き。
- フォントはかなり小さい。iPhone幅で読み切れるサイズ、11-13pt程度。
- 行間は詰めすぎず、現スクショと同じ密度を目標。

Ask Anything:

- コンテンツにoverlayで重なる。
- 横幅は画面左右約10-12pt余白。
- 中央やや下に浮く。
- スクロールしても下部固定。
- 本文が隠れるのは許容。スクショでは明確に重なっている。

## File Detail / Generated Transcript

- 上部構成はSummaryと同じ。
- 選択タブは `文字起こし`。
- 見出し `文字起こし`。
- 発話者ごとのブロック:
  - `SpeakerA` 太字。
  - 時刻 `00:00:00` 薄グレー。
  - その下に本文。
- 本文は長文。左右余白は狭め。
- Ask Anythingバーが本文上に重なる。

## File Detail / Memo

- 上部構成は同じ。
- 選択タブは `メモ`。
- 画像アップロード横スクロールまで表示。
- 本文は空。
- Ask Anythingバーが中央付近に浮いている。

## Recording Bottom Sheet

ホームの録音開始後:

- 背景ホームはそのまま見える。
- 下から大きなLiquid Glassボトムシート。
- シート上端にドラッグインジケータ。
- 角丸大きめ。
- ファイル名:
  - `20260430_1101録音.mp3`
  - 太字、中央。
- 経過時間:
  - `00:01:01`
  - 大きめ、太字、中央。
- 波形:
  - 左側赤、右側グレー。
  - 中央に赤い縦線と赤い丸。
- 下部ボタン:
  - 左 `Pause`
    - 薄グレー背景、黒文字、pauseアイコン。
  - 右 `Stop`
    - 赤背景、白文字、stopアイコン。
  - 両方大きなピル。

## State Mapping

Home:

- `selectedHomeSegment == .files`: ファイルカード一覧。
- `selectedHomeSegment == .projects`: 2カラムプロジェクト一覧 + プロジェクト作成 + Ask Anything。
- `isFABExpanded`: FABメニュー表示。
- `isRecording`: 録音ボトムシート表示。

File Detail:

- `selectedTab == .summary`: 生成後の要約。
- `selectedTab == .transcript`: 生成前は空状態/生成CTA、生成後は文字起こし。
- `selectedTab == .memo`: メモ空状態。
- `generationState == .notGenerated`: 生成CTA。
- `generationState == .choosingMode`: 生成方式シート。
- `generationState == .choosingTemplate`: テンプレート選択シート。
- `generationState == .choosingModel`: AIモデル選択シート。
- `generationState == .loading`: スケルトン。
- `generationState == .generated`: Summary/Transcript/Memo本文。

## Implementation Notes

- SwiftUIの `List` は使わない。余白、separator、背景、スクロール挙動がスクショとズレやすい。
- `ScrollView` + `LazyVStack` / `LazyVGrid` を使う。
- 標準 `NavigationStack` は遷移管理だけに使い、navigation title/barは隠す。
- 上部ボタン群は `safeAreaInset` かカスタム `VStack` で自前配置。
- ボトムシートは標準 `.sheet` のdetentだけではスクショと違いやすい。必要なら `ZStack` overlay + custom bottom sheetを実装。
- タブバーも標準 `TabView.tabItem` ではなく、スクショ一致が必要ならカスタムFloatingTabBarを使う。
- 既存の `LiquidGlassModifier` がiOS 26で `glassEffect` を使っているなら流用してよい。ただし複数要素のまとまりは `GlassEffectContainer` を使う。
- ロゴ/製品画像/サムネイルは仮アイコンで済ませない。画像が必要な箇所はAssetsに追加する。
- SF Symbolsで再現できる箇所:
  - back: `chevron.left`
  - play: `play.fill`
  - share: `square.and.arrow.up`
  - more: `ellipsis`
  - search: `magnifyingglass`
  - upload: `square.and.arrow.up`
  - waveform: `waveform`
  - document: `list.bullet.rectangle`
  - plus: `plus`
  - close: `xmark`

## Pixel QA Checklist

実装後に必ずスクリーンショットを撮り、添付スクショと比較する。

- 背景色が白すぎないか、暗すぎないか。
- 上部PLAUDボタンの位置、幅、高さが一致しているか。
- AAボタンが内外2重円に見えるか。
- 検索バーの高さと左右余白が一致しているか。
- ファイル/プロジェクト選択ピルの位置がズレていないか。
- ファイルカードの横幅、角丸、カード間隔が一致しているか。
- 要約ボックスの高さ、余白、角丸が一致しているか。
- 処理中カードの進捗バーの位置と太さが一致しているか。
- FABとタブバーの距離が一致しているか。
- Liquid Glassが単なる白塗りに見えていないか。
- ボトムシートの上端位置、角丸、ドラッグバーが一致しているか。
- 詳細画面の上部ボタン群が標準ナビゲーションっぽくなっていないか。
- Ask Anythingバーがスクショ通り本文に重なるか。
- 生成後の長文表示の文字サイズ/行間/左右余白が一致しているか。
- iOS 26シミュレータでLiquid Glassが有効か。
- iOS 17-25でもクラッシュせず、フォールバック表示になるか。

## Non-Goals

- 今回は新しい機能仕様を追加しない。
- AI生成ロジックや文字起こし精度は対象外。
- データモデル変更は原則しない。
- UI再現に不要な大規模リファクタはしない。

