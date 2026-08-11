# Memora デザイン禁止事項（Prohibitions）

- 更新日: 2026-08-02
- 位置付け: レビュー可能な禁止リスト。判定基準は「客観的レビューテスト」で示す。
- 関連: [`MEMORA_DESIGN.md`](./MEMORA_DESIGN.md) / [`component-map.md`](./component-map.md) / [`screen-patterns.md`](./screen-patterns.md)

適用範囲: 新規実装・移行中のコード。既存コード（例: `src/design/tokens.ts`、
既存 `FileCard`）は対象外とし、移行時に順次解消する。

## 1. ビジュアルシステム

1. 生のHEX・gray-number（`#333`、`gray`、`#A3A3A3` 等）を UI に直接書く。
   **テスト**: コンポーネント / スタイルから `#[0-9A-Fa-f]{3,8}` 直書きを grep。
   トークンファイル以外で許可しない。
2. 意味論トークン（`colors.*`）ではなく気分で色を足す。
   **テスト**: トークンに無い色キーが使われていないこと。
3. 赤を録音・危険以外（装飾・ブランド・成功等）に使う。
   **テスト**: `recording` / `danger` ロール以外に赤系HEXを使わない。
4. 状態を色だけで符号化する（例: 赤=録音中と暗黙に理解させるだけ）。
   **テスト**: 状態表示は必ずラベル / 図形 / 音のいずれかを併設。

## 2. 階層 / レイアウト

1. 影で階層を作る。**テスト**: `shadowOpacity` / `elevation` は
   `shadow.none` / `shadow.floatingNav` / `shadow.recordingFab` の値以外を書かない。
2. 4pt基底でない任意の余白値（11, 17, 23 等）。
   **テスト**: `space` / `grid` / `screenMargin` に無い数値の padding / margin / gap。
3. 画面左右マージンを 16 / 20 以外にする（明示的な特例なし）。
   **テスト**: `screenMargin.compact` / `regular` 以外の水平パディング。
4. 内部リズム 8pt を破る（コンポーネント内の縦間隔の揺れ）。
   **テスト**: `grid.rhythm` の倍数以外で縦間隔を積む。
5. 装飾目的の空カード・空スペースで情報のなさを隠す。
   **テスト**: 意味のあるコンテンツを含まない `Card` / `Surface` が存在しない。

## 3. タイポグラフィ

1. フォントパッケージ / 装飾用ディスプレイフォントを導入する。
   **テスト**: package.json にフォントライブラリを追加しない。
2. トークンに無い `fontSize` を直書きする。
   **テスト**: `typography.size` 外の fontSize。
3. メタデータを大見出しと同じ大きさにする（対比の喪失）。
   **テスト**: メタデータ（日時・長さ等）に `footnote`（13）より大きいサイズを使わない。
4. Dynamic Type を無効化する（`allowFontScaling={false}`、固定行間）。
   **テスト**: 行間を固定pxで積む場合、拡大時を考慮していること。`allowFontScaling={false}` を禁止。
5. 可読性を壊す letterSpacing / lineHeight 比（×1.5 未満は本文で禁止）。

## 4. インタラクション / 状態

1. タップ領域 44pt 未満（`touchTarget.min`）。
   **テスト**: `Button isIconOnly` 等が 44×44 未満のコンテンツは `hitSlop` で補うこと。
2. 押下 / 選択 / 無効 / ローディングの状態を実装しない。
   **テスト**: 操作可能な要素が `PressableFeedback` or pressed 状態を持つこと。
3. 状態を色のみで切り替える。
   **テスト**: disabled / selected に非色の手掛かり（ラベル / 図形 / trait）が無いものを禁止。
4. 決定性の進捗が分かるのに `Spinner` だけにする、逆に不確定なのに 0-100% を偽装する。
   **テスト**: 実測値が無いのに `ProgressBar` を使わない。
5. `onClick`（Web）や Web 専用イベントを使用する。
   **テスト**: コンポーネントに `onClick` を grep。`onPress` を使う。

## 5. カード / サーフェス

1. リスト行（ファイル・プロジェクト・タスク・設定行）を `Card` で表現する。
   **テスト**: `ListGroup` または `Surface` + `Separator` で実装できる行に `Card` を使わない。
2. `Card` を装飾的に連打する（cards-inside-cards）。
   **テスト**: `Card` の中に `Card` をネストしない。
3. `surfaceElevated` を日常のカード・行に流用する。
   **テスト**: `surfaceElevated` はオーバーレイ / 浮遊要素専用。
4. 影の無い境界（`Surface`）と装飾の区別をなくすために影を使う。
   **テスト**: §2.1 に従う。

## 6. Liquid Glass

1. Liquid Glass をナビゲーション・FAB・主要録音コントロール以外に使う。
   **テスト**: `LiquidGlassView` / `LiquidGlassContainerView` の利用箇所を3用途（ナビゲーション / FAB / 主要録音コントロール）に限定。
2. ガラスを装飾（背景全面・装飾ブロック）に使う。
   **テスト**: 操作面以外のガラス使用を禁止。
3. フォールバック（iOS 26未満 / Android）を実装しない。
   **テスト**: 旧来のビュー・ライブラリの利用ではなく、
   `glassFallback` / `glassBorderFallback` を使う不透明 `Surface` / `View` へのフォールバックが必須。
4. ガラス面のテキスト可読性を保証しない（`foregroundPrimary` 未使用）。
   **テスト**: ガラス上のテキストはコントラスト比を確認。

## 7. データ / ステータス可視化

1. 波形・タイマー等を色だけに頼る（ラベルなし）。
   **テスト**: `RecordingWaveform` には `RecordingTimer` + ラベルを併設。
2. 処理中を示すラベルを付けずに `Spinner` / `ProcessingRail` だけ表示する。
   **テスト**: 「文字起こし中」「要約中」等のテキストを併記。
3. 正確な値（時刻・長さ・進捗）を丸め・偽装する。
   **テスト**: `AudioTimeline` / `RecordingTimer` は実値から描画。
4. 話者表示を色だけにする。
   **テスト**: `TranscriptSegment` は話者名・時刻のテキストを併記。

## 8. アクセシビリティ

1. 最小タップ領域 44pt 未満（§4.1 再掲）。
   **テスト**: `touchTarget.min` 未満の操作要素は `hitSlop` で補正。
2. アイコン単体ボタンに `accessibilityLabel` が無い。
   **テスト**: `isIconOnly` / アイコン中心の操作にラベル必須。
3. 状態（選択・無効・処理中）を trait / ラベルで伝えない。
   **テスト**: `accessibilityState`（`selected` / `disabled` / `busy`）を使用。
4. VoiceOver で装飾要素が読まれる / 操作要素が読まれない。
   **テスト**: 区切り・アイコン装飾は `accessibilityElementsHidden` 等で隠す。
5. Dynamic Type / Reduce Motion / Reduce Transparency / Increased Contrast を考慮しない。
   **テスト**: `allowFontScaling`、`motion.reducedDuration` への差替え、
   `glassFallback`、コントラスト強化パスを確認。

## 9. 技術実装

1. HeroUI Native 未導入なのに「導入済み」前提のコードを書く。
   **テスト**: package.json の `heroui-native` 追加前は、`heroui-native` の import をしない。
2. 既存 `src/design/tokens.ts` を削除・リネームして import を破壊する。
   **テスト**: 既存の `../design/tokens` import が動き続けること（移行時はリエクスポート）。
3. トークンモジュールから `react-native` 以外のライブラリ（HeroUI Native、フォント等）へ依存する。
   **テスト**: `src/theme/tokens.ts` の import は `react-native`（`StyleSheet`）のみ。
4. 4pt基底グリッドを破るコンポーネントを `theme` に直接埋め込む。
   **テスト**: トークンは値だけを持ち、レイアウトロジックを持たない。
5. アイコンサイズ・タップターゲットをトークン外で定義する。
   **テスト**: `icon` / `touchTarget` を使う。
6. 不要なシャドウを `shadow` 外で定義する（§2.1 と同一）。
