# 最終設計レビュー

作成日: 2026-07-26
対象: 本フェーズで作成した設計資料一式

## 自己レビュー結果

### HeroUI Native と Web を混同していないか

**問題なし。**

- 使用パッケージを `heroui-native` に統一。`@heroui/react` は `docs/design/codex-execution-rules.md` で明示的に禁止した
- `npx skills add heroui-inc/heroui` により `heroui-react`（Web版）も同時に導入されたが、**使用禁止として記録済み**
- イベントは `onPress` で統一。`onClick` は使っていない
- スタイリングは Uniwind（NativeWind ではない）と明記

### 存在しないコンポーネントを書いていないか

**機械的に検証済み。**

`node .agents/skills/heroui-native/scripts/list_components.mjs` で取得した実在 39 コンポーネントと、本フェーズで作成した 29 ファイル内の記述を突き合わせた結果、**実在しないコンポーネントの混入はなかった**。

独自実装として明記したもの（`ProgressBar` `RecordingWaveform` `RecordingTimer` `TranscriptSegment` `TabBar` `RecordingStatusBar`）は、HeroUI に該当が無いことを確認したうえで独自と宣言している。

**特に重要な発見**: `Progress` / `ProgressBar` が HeroUI Native に存在しない。決定的進捗の表示手段が無いため独自実装が必須である。これを見落とすと `Slider` を進捗表示に誤用する危険があった。

### 最新 API を確認したか

**確認済み。** 記憶ではなく公式 Skill から取得した。

| 確認項目 | 結果 |
|---|---|
| コンポーネント一覧 | 39件（v1.0.3） |
| `Card` の slot | `.Header/.Title/.Description/.Body/.Footer` |
| `ListGroup` の slot | `.Item/.ItemContent/.ItemTitle/.ItemDescription/.ItemPrefix/.ItemSuffix` |
| `BottomSheet` の slot | `.Portal/.Overlay/.Content/.Title/.Description/.Trigger/.Close` |
| `Dialog` の slot | 同上 |
| `Tabs` の slot | `.List/.Trigger/.Label/.Indicator/.Content/.ScrollView/.Separator` |
| `Alert` の slot | `.Indicator/.Content/.Title/.Description` |
| テーマ形式 | **OKLCH**（指示にあった HSL ではない） |

テーマが OKLCH である点は、指示（HSL 前提）と実際が異なっていた。**実際の仕様に合わせて記述した。**

### Primary CTA が明確か

**問題なし。** 各画面で Primary action を1つに限定した。

| 画面 | Primary |
|---|---|
| ホーム | 会議を開く（録音は中央 CTA が担う） |
| ライブラリ | 会議を開く |
| 録音セットアップ | 録音を開始 |
| 録音中 | 停止 |
| 会議詳細 | 読む（操作は補助） |
| タスク | 完了にする |

**1画面に Primary が複数存在する箇所は無い。**

### 各画面の目的が1つに絞られているか

**改善済み。** 監査 H-3 で指摘した FileDetailScreen（1,419行）の機能集中を、次のように分離した。

- 会議詳細 = **読む**
- 編集・書き出し・削除 = Bottom Sheet / Dialog
- AI 質問 = 文脈付き Bottom Sheet（旧 Ask タブを廃止）
- メモ = 要約タブ内のセクション（メモタブを廃止）

### 情報階層が一貫しているか

**問題なし。** 全画面で「最重要情報を初期表示領域に置く」原則を守った。

- ホーム: 処理中 → 最近 → タスク
- 会議詳細: タイトル・日時 → 状態 → タブ内容
- 録音中: 録音中の表示 → 経過時間 → 波形 → 操作

### 片手操作が考慮されているか

**改善済み。** 監査 H-4 の解決として次を設計した。

- 中央録音 CTA を親指の自然な位置に配置
- 録音中の主要操作（一時停止・停止）を画面下部に集約
- グローバル録音バーで画面遷移なしに停止できる
- ヘッダーは文脈表示（タイトル・戻る）に限定

### 空状態と失敗状態が定義されているか

**全画面で定義済み。**

- 空状態には**必ず CTA を持たせる**（`docs/design/components.md` の `EmptyState` で「CTA の無い空状態を作らない」と規定）
- 失敗には**必ず再試行または代替手段を添える**（同 `ErrorState`）
- `docs/design/screens/processing.md` で処理の各段階の失敗を網羅した

### iOS / Android 差異が考慮されているか

**部分的。**

考慮した点:
- Android の戻る操作で録音を停止しない
- Safe Area の扱いを明記
- 各タスクに iOS / Android 確認項目を設けた

**不十分な点**: Android 固有の Material 的な期待（リップル、システムバック手勢）への対応は未定義。実装フェーズで判断が必要。

### Codex が推測せず実装できるか

**おおむね可能。** ただし以下は実装時の判断が残る。

- 色の実値（低彩度・ブランド整合の範囲で提案としたため）
- Dynamic Type の実装方法（方針のみ示し、手段は委ねた）
- `RecordingWaveform` の実装手段（Skia か Reanimated か）

これらは `docs/design/codex-execution-rules.md` の「仕様不足時の対応」に従い、`docs/reviews/implementation-questions.md` へ記録させる。

### 既存仕様との矛盾が記録されているか

**記録済み。**

| 指示 | 実際 | 対応 |
|---|---|---|
| テーマは HSL 形式 | **OKLCH** | 実際に合わせて記述 |
| `heroui-native` Skill を `curl` で導入 | `npx skills add` の方が Claude / Codex 双方へ配置できる | 後者を採用し理由を記録 |
| `/plugin install expo@claude-plugins-official` | 本環境で利用不可 | `npx skills add expo/skills` を採用 |
| CLAUDE.md §9 の行間 1.45〜1.62 | 見出しは 1.22〜1.40 が適切 | 本文系の規定と解釈し、`design-system.md` に明記 |

### アクセシビリティ要件が具体的か

**具体化済み。** 各画面仕様に個別の要件を記載した。

- タップ領域 44pt（例外なし）
- 読み上げの単位（カードを1つの意味単位にまとめる等）
- `accessibilityRole` / `accessibilityState` の具体的な指定
- **色だけで状態・話者を表さない**
- Reduce Motion 時の代替表現
- **Dynamic Type 対応を必須化**（現状未対応の最大の課題）

## 残る懸念

### 1. 実装規模が大きい

24タスク、うち「大」規模が4件。既存実装との差分が大きく、段階的な移行計画が必要。

`docs/design/implementation-plan.md` でフェーズを6段階に分け、各フェーズの完了条件を定義した。**フェーズ3（録音 → 処理 → 確認）が通れば主要動線は確保される。**

### 2. 既存コードの扱い

現状 `apps/mobile-expo/src/` には作業ツリー上の未コミット変更（構造系4ファイル）が残っている。本設計の適用前に、採否を判断する必要がある。

### 3. データモデルへの影響

「File → Meeting」の概念変更は UI 層の話だが、`src/types/memora.ts` や SwiftData スキーマとの整合が必要になる可能性がある。**本設計では UI 層のみを定義した。** データ層の変更要否は実装フェーズで確認が必要。

### 4. Android 検証環境

現状 `apps/mobile-expo/android` が存在せず iOS 専用構成。Android 確認項目を各タスクに設けたが、**実行環境が無い**。

## 総合評価

設計としての一貫性は確保できた。特に次の3点が本フェーズの中核的な成果である。

1. **録音をナビゲーション構造の一級市民にした**（監査 C-1 の根本解決）
2. **File 概念を廃止し Meeting に統一した**（監査 C-3 の根本解決）
3. **HeroUI の compound component 構造を正しく前提にした**（以前の「root だけ借りる」実装が違和感の原因だった）

実装可能性についても、API を実測で確認し、存在しないコンポーネントを排除したため、Codex が推測で埋める余地を最小化できた。
