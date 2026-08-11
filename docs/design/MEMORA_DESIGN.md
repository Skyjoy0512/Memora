# Memora デザイン仕様（Palantir原則をiOS React Nativeへ適応）

- 更新日: 2026-08-02
- 状態: デザインターゲット（一部ロールは未実装の目標記述）
- 関連:
  - トークン: [`apps/mobile-expo/src/theme/tokens.ts`](../../apps/mobile-expo/src/theme/tokens.ts)
  - コンポーネント対応: [`component-map.md`](./component-map.md)
  - 画面パターン: [`screen-patterns.md`](./screen-patterns.md)
  - 禁止事項: [`prohibitions.md`](./prohibitions.md)
  - IA（変更対象外）: [`information-architecture.md`](./information-architecture.md), [`navigation.md`](./navigation.md), [`navigation-flow.mmd`](./navigation-flow.mmd), [`screen-inventory.md`](./screen-inventory.md)

## 1. ソースとその限界

本稿の「Palantir原則」は、作業空間に存在しない `PALANTIR_REFERENCE_DESIGN.md`
から直接引用したものではない。**依頼者が抽出・提供した原則リスト**を正本とし、
元リファレンス自体は未読である（読了を主張しない）。

したがって本稿は、元リファレンスのロゴ・商標・プロプライエタリ資産・特定の
ページ構成・マーケティング文言を一切再現しない。抽出原則から「ロジックと
規律」だけを取り出し、Memora 固有の情報構造（録音・文字起こし・要約・
タスク・プロジェクト・Ask AI）へ変換する。

## 2. デザイン方針（Thesis）

Memora は「正確さ」を扱う運用ツールである。装飾を減らし、情報構造・状態・
進捗を正確に示すこと自体が美しさの源泉になる。

- **モノクロ基調で一貫する**。色は意味（録音・危険・成功・警告）のためだけに使う。
- **階層は色より重みとトナルサーフェスで作る**。影はデフォルトの階層手段にしない。
- **大見出しと小さなメタデータの対比**で、どこが重要かを一瞬で読ませる。
- **レイアウトが情報構造を露出する**。装飾で埋めるのではなく、空気と整列で示す。
- **技術的・正確・運用志向のキャラクタ**。無骨さを恐れず、緩さを排除する。

## 3. 保存する原則（Preserved Principles）

1. モノクロ基調パレット（monochrome-first）
2. 厳格グリッド（strict grid）
3. 大見出しと小さなメタデータのコントラスト
4. ヘアライン枠線（hairline borders）
5. 情報構造を露出するレイアウト
6. 技術的・正確・運用志向の性格
7. 装飾的カードの乱用を避ける

これらは「見た目のコピー」ではなく、設計判断の前提として引き継ぐ。

## 4. モバイル製品へ変換する原則（Transformations）

| # | 元（Web/マーケティング） | 変換先（iPhone / RN） |
|---|---|---|
| 1 | 横長Webコンポジション | 縦並びのモバイルシーケンス（1カラム、垂直リズム） |
| 2 | hover | pressed / focused / selected / disabled / loading の明示状態 |
| 3 | Webナビゲーション | Expo Router の Bottom Tabs（NativeTabs）+ Stack Navigation |
| 4 | マーケティング規模のタイポ | 可読なiPhoneタイポグラフィ + Dynamic Type 対応 |
| 5 | マーケティング動画 | 録音波形・文字起こし状態・AI処理状態の可視化 |
| 6 | ページ構成 | HeroUI Native コンポーネントへマップ（`component-map.md`） |
| 7 | 全面ガラス表現 | Liquid Glass はナビゲーション・FAB・主要録音コントロールに限定 |

## 5. グリッドと余白（4pt基底）

- **4pt基底**を採用し、名称付き倍数のみ使う（`tokens.ts` の `grid` / `space`）。
- 画面左右マージン: **compact 16pt / regular 20pt**。
- 内部リズム: **8pt**（リスト行間・コンポーネント内の縦リズム）。
- セクション間: 20〜32pt。**任意の一回限り値（11pt, 17pt 等）を禁止**する。
- 階層の創出は余白・整列・トナルサーフェス・ヘアラインを優先し、影は使わない。

## 6. モノクロ基調の意味論パレット

意味論名は gray-number ではなく役割名（`foregroundPrimary`, `surfaceAlt` 等）。
定義は [`tokens.ts`](../../apps/mobile-expo/src/theme/tokens.ts) の `colors.light` / `colors.dark`。

| ロール | 使われ方 |
|---|---|
| `canvas` | 画面の最背面。リストやセクションの地 |
| `surface` / `surfaceAlt` | 表面レベル1/2。グループ化された面（設定のグループ等） |
| `surfaceElevated` | シート・メニュー・浮遊要素の面 |
| `surfaceInverse` | 反転面（Chip の強調、反転ボタン等） |
| `foregroundPrimary/Secondary/Tertiary/Quaternary` | テキスト階層。大見出し=Primary、メタデータ=Tertiary/Quaternary |
| `foregroundInverse` | 反転面の上テキスト |
| `border` / `borderStrong` / `hairline` | 枠線。通常=hairline、強調=borderStrong |
| `selection` / `selectionForeground` | 選択状態のトナル背景とその前景 |
| `focus` | フォーカスリング（キーボード/アクセシビリティカーソル） |
| `accent` / `accentSoft` | モノクロの強調。リンク・重要要素を重みで強調 |
| `recording` / `recordingSoft` | 録音。**赤は録音と危険の意味論例外のみ** |
| `danger` / `dangerSoft` | 破壊的操作・エラー |
| `processing` / `processingSoft` | 処理中（文字起こし・要約）。モノクロの中立グレー |
| `success` / `successSoft` | 完了・成功 |
| `warning` / `warningSoft` | 警告・注意 |
| `info` / `infoSoft` | 補足情報 |
| `scrim` / `scrimLight` | オーバーレイ減光（Liquid Glass 不使用端末のフォールバック含む） |
| `glassFallback` / `glassBorderFallback` | Liquid Glass 非対応端末（iOS 26未満・Android）のマテリアル代替 |

**ルール**: 赤は録音・危険のみ。**状態を色だけに頼らない**（図形・文字・音・
ラベルと併用）。録音は「赤 + 波形 + タイマー + ラベル」で重ねて明示する。

## 7. タイポグラフィ階層

プラットフォーム System フォントを使用し、フォントパッケージに依存しない。
日本語はシステムCJKフォールバック（Hiragino / Noto Sans CJK）に任せる。
装飾用ディスプレイフォントは指定しない。

| 役割 | サイズ | 用途 |
|---|---|---|
| `largeTitle` | 34 | 画面見出し（ホーム等） |
| `title1` | 28 | 詳細画面見出し |
| `title2` | 22 | サブ見出し |
| `title3` / `headline` | 20 / 17 | セクション見出し・強調 |
| `body` | 17 | 本文・文字起こし本文 |
| `subheadline` / `callout` | 15 / 16 | 二次情報 |
| `footnote` | 13 | メタデータ（日時・長さ・話者数等） |
| `caption1` / `caption2` | 12 / 11 | ステータス・弱いメタデータ。wide tracking 併用 |

- 行間は比率（×1.5 前後）で扱い、**Dynamic Type 拡大時も比例**するようにする。
- メタデータは小さく・`wide` トラッキングで、大見出しとのコントラストを作る。
- 重みは `regular` / `medium` / `semibold` / `bold`。装飾的な極太・極細は控える。

## 8. 枠線とサーフェス

- 枠線は `StyleSheet.hairlineWidth`（1物理画素）を基本とする。
- 階層は「サーフェスのトーン差 + ヘアライン + 余白」で作る。影は原則禁止。
- リスト行はカード化せず、`surface` + `Separator`（ヘアライン）で区切る。
- `surfaceElevated` はオーバーレイ・浮遊要素だけに使い、日常のカードに流用しない。

## 9. 状態（States）

| 状態 | 表現 |
|---|---|
| pressed | 押下フィードバック（トナル反転 or 半透明 + 微細なスケール）。`opacity.pressed` |
| focused | フォーカスリング（`focus` 色）。キーボード / VoiceOver カーソルで可視化 |
| selected | トナル背景 `selection` + 前景 `selectionForeground`、必要なら図形（チェック等） |
| disabled | `opacity.disabled`（0.38）。押下フィードバック無効。状態は色だけにしない |
| loading | 決定性は `ProcessingRail`、不確定は `Spinner` / `Skeleton`（形が既知なら `SkeletonGroup`） |

状態の違いは**必ず一要素以上の非色の手掛かり**を持つ。

## 10. モーションとフィードバック

- フィードバックは小さく、速く、意図的であること。
- 既定: `motion.duration`（fast 120 / normal 200 / deliberate 320 / slow 480ms）。
- スプリング: `motion.spring`（control / sheet / fab / subtle）を用途別に使う。
- **Reduce Motion 有効時**は `motion.reducedDuration` へ差し替え、移動・スケール・
  スクロール駆動を止め、フェード（または即時表示）のみ残す。実行時検出は
  `AccessibilityInfo` / `useReducedMotion` 系フックでアプリ側が行う。
- 触覚（haptics）は録音開始・停止・完了などの意味のある場面のみ。

## 11. アクセシビリティ

- 最小タップ領域 **44pt**（`touchTarget.min`）。FAB は 56pt。
- **Dynamic Type**: システムフォント + `allowFontScaling=true`、行間は比率。
- **Reduce Motion**: §10 の代替値へ差し替え。
- **Reduce Transparency**: Liquid Glass を不可視化または `glassFallback` /
  `glassBorderFallback` を使う不透明な Surface/View へ切替。
- **Increased Contrast**: `borderStrong` / `foregroundPrimary` を優先して使用。
- **VoiceOver**: 操作要素に意味のあるラベルとヒント、`selected` / `tab` 等の
  trait、状態を color-only で伝えない。録音波形はラベル + タイマーで代替情報を提供。
- 詳細は [`prohibitions.md`](./prohibitions.md) §8。

## 12. Liquid Glass の適用制限

Liquid Glass（iOS 26 以上の `@callstack/liquid-glass`）は**3箇所に限定**する。

1. ナビゲーション（NativeTabs まわり / BottomAccessory の外枠）
2. 中央FAB（作成メニューのトリガー）
3. 主要録音コントロール（録音開始・停止）

- 非対応OS（iOS 26未満・Android）・Reduce Transparency・利用不能時は、
   意味論色 `glassFallback` / `glassBorderFallback` を使う不透明な
  Surface/View に切替える。
- ガラスを単なる装飾に使わない。ガラスは「常時見える操作面」のために使う。
- ガラス面の可読性は、テキストを `foregroundPrimary` で保証する。

## 13. 既存情報設計（IA）との関係

本稿は IA を変更しない。以下を正本としてそのまま尊重する。

- [`information-architecture.md`](./information-architecture.md): NativeTabs
  （ホーム / タスク / AI / 設定）+ 中央FAB + BottomAccessory AIコンポーザー。
- [`navigation.md`](./navigation.md): Stack（file/[id]）、fullScreenModal（record）、
  modal（search / import / online meeting）。
- [`navigation-flow.mmd`](./navigation-flow.mmd): 画面遷移の全体フロー。
- [`screen-inventory.md`](./screen-inventory.md): 本番ルート一覧。

デザインは既存ルート・画面責務の上に載る。**「ファイル」表記の維持、
「ホーム/ライブラリ分離なし」、AIタブ維持、独自TabBarなし**を前提にする。
画面別の縦構成は [`screen-patterns.md`](./screen-patterns.md) に定義する。

IA文書内の旧ビジュアル実装記述より、本稿および [`component-map.md`](./component-map.md) の
技術契約が優先される。

## 14. 意思決定チェックリスト

実装・レビュー時に下記を全て満たすこと（判定基準は [`prohibitions.md`](./prohibitions.md) 参照）。

- [ ] 色は意味論トークンからのみ取得し、gray-number / 生HEX を使わない
- [ ] 赤は録音・危険のみ。状態は色だけにしない
- [ ] 余白は4pt基底の名称付き倍数（16/20マージン、8リズム）
- [ ] 影は `shadow.floatingNav` / `shadow.recordingFab` 以外使わない
- [ ] リスト行はカード化しない（Surface + Separator を使用）
- [ ] メタデータは small + wide tracking。大見出しとの対比を保つ
- [ ] 最小タップ領域 44pt を満たす
- [ ] Dynamic Type / Reduce Motion / Reduce Transparency / Increased Contrast /
      VoiceOver が考慮されている
- [ ] Liquid Glass はナビゲーション・FAB・主要録音コントロールのみ
- [ ] 未実装状態は `Skeleton` / `Spinner` / `ProcessingRail` で明確に示す

## 15. 参照

- トークン定義: [`apps/mobile-expo/src/theme/tokens.ts`](../../apps/mobile-expo/src/theme/tokens.ts)
- コンポーネント対応: [`component-map.md`](./component-map.md)
- 画面パターン: [`screen-patterns.md`](./screen-patterns.md)
- 禁止事項: [`prohibitions.md`](./prohibitions.md)
- トークン移行（既存 `src/design/tokens.ts` の取扱い）: `tokens.ts` 冒頭コメント
