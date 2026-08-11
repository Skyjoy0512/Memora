# Codex 実行ルール

作成日: 2026-07-26
適用対象: Memora の UI 実装を行うすべての Codex タスク

## Source of Truth

設計資料には旧案も残るため、次の優先順を正本とする。実装時に順序を入れ替えたり、旧案を合成したりしない。

| 種類 | 参照先 |
|---|---|
| 最終決定 | `docs/decisions/ADR-001-navigation-architecture.md` |
| 情報設計 | `docs/design/information-architecture.md` |
| ナビゲーション | `docs/design/navigation.md` |
| 実装順 | `docs/design/implementation-plan.md` |
| コンポーネント選定 | `docs/design/heroui-component-map.md` |
| デザイントークン | `docs/design/design-tokens.md` |
| 画面仕様 | `docs/design/screens/*.md` |
| 文言 | `docs/design/ux-copy.md` |
| 共通部品 | `docs/design/components.md` |

## 技術上の絶対条件

### 使用するもの

- パッケージ: **`heroui-native`**
- スタイリング: **Uniwind**（Tailwind CSS v4）
- イベント: **`onPress`**
- Provider: `HeroUINativeProvider`, `GestureHandlerRootView`, `BottomSheetModalProvider`
- テーマ: Light / Dark 両対応。**OKLCH 形式**

### 禁止事項

- **`@heroui/react`（HeroUI Web）の使用**
- HeroUI Web の API を React Native へ流用すること
- DOM 要素の前提
- **`onClick` の使用**
- Web 用 Tailwind の挙動を前提にすること
- HeroUI Web の Card 構造の流用
- **実在を確認していない HeroUI Native コンポーネントの使用**
- **NativeWind 前提の設計**（本プロジェクトは Uniwind）
- HeroUI Native 以外の総合 UI ライブラリの併用
- 独自 UI コンポーネントの無制限な追加

次のExpo公式モジュールは最新設計で採用済みのため、対象タスク内で追加してよい: `expo-glass-effect`、`expo-symbols`、`expo-blur`。追加前にExpo SDK 57互換版を確認し、iOS 26未満とAndroidのフォールバックを同じPRに含める。

## API 確認の義務

**記憶で API を推測しない。** 必ず公式 Skill で確認する。

```bash
node .agents/skills/heroui-native/scripts/list_components.mjs
node .agents/skills/heroui-native/scripts/get_component_docs.mjs <Component>
node .agents/skills/heroui-native/scripts/get_theme.mjs
```

**存在が確認できないコンポーネントは使わない。** 代替を `docs/reviews/implementation-questions.md` に記録して報告する。

既知の非存在: `Progress` / `ProgressBar` / `Badge` / `Fab` / `SegmentedControl` / `Toolbar`

## コンポーネント選定のルール

1. **HeroUI 標準で実現できるものは標準を使う**
2. ラッパーを作るのは `docs/design/components.md` に定義された9種のみ
3. 独自実装は同ドキュメントの5種のみ
4. **それ以外のカスタムコンポーネントを追加する場合は、理由を `docs/reviews/implementation-questions.md` に記録する**

### compound component の扱い

HeroUI は **root が状態・テーマ・コンテキストを担い、compound slot が内部構造を担う**設計である。

**root だけ使って中身を自前で組まない。** 例:

```tsx
// 誤り: 外枠だけ借りて中身が自前
<Card>
  <View style={styles.header}>
    <Text style={styles.title}>{title}</Text>
  </View>
</Card>

// 正しい: slot を使う
<Card>
  <Card.Header>
    <Card.Title>{title}</Card.Title>
  </Card.Header>
</Card>
```

`SearchField` は root の `value` / `onChange` を `Input` / `ClearButton` に供給するため、自前の入力レイアウトで包むと機能しない。

## デザイン上の制約

- **影を使わない。** 階層は面のトーン差（`surface` / `surface-secondary` / `surface-tertiary`）とヘアラインで表現する
- **色を直接指定しない。** セマンティックトークンを使う
- **巨大余白を使わない。** 黄金比スケール（3/5/8/13/21/34/55）を守る
- **タップ領域 44pt 未満を作らない**
- **状態を色だけで表さない。** 必ずテキストを伴う
- 入れ子は同心円の角丸（内側 = 外側 − padding）

## UX 仕様の変更禁止

- 画面の目的、情報の順序、操作の位置を勝手に変えない
- 文言は `docs/design/ux-copy.md` に従う。**技術用語をユーザーに見せない**
- 不明点を推測で埋めない

## 実装後の確認義務

各タスク完了時に以下を実施し、結果を報告する。

### 必須検証

```bash
npm run typecheck
npx expo export --platform web
npm run theme:check
git diff --check
```

`npm run qa:ios:build` は Codex のサンドボックスでは実行できない（`CoreSimulatorService` 接続拒否）。依頼者側で実行する。

### 目視確認

- **iOS / Android のスクリーンショットを取得する**
- **Dark Mode で確認する**
- **Dynamic Type を最大にして確認する**
- **VoiceOver ラベルを確認する**
- **44pt 未満のタップ領域が無いことを確認する**

## 仕様不足時の対応

推測で実装せず、`docs/reviews/implementation-questions.md` に記録する。

記録形式:

```markdown
## Q-{番号}: {要約}

- 発生タスク: MEM-UI-{番号}
- 該当箇所: {ファイル / 画面}
- 不明な点: {具体的に}
- 実装をブロックするか: はい / いいえ
- 暫定対応: {ブロックしない場合、どう実装したか}
```

**ブロックする場合は作業を止めて報告する。**

## 環境上の注意

- リポジトリは外付け SSD 上にある。切断でファイルが 0 バイトや切り詰めで壊れることがある
- 不可解なエラーが出たら `find node_modules -type f -size 0 -name "*.ts"` で整合性を確認する
- `node_modules.interrupted-*` があれば削除する
- **`expo prebuild` を実行しない。** 手書きの iOS ホストが消える
- §8 の文字起こしコア保護ファイルを編集しない
