# Skill 導入レポート

作成日: 2026-07-26
目的: Memora の UI/UX 全面再設計にあたり、設計判断の根拠となる公式ドキュメントと設計知見を Claude / Codex 双方から参照できる状態にする。

## 導入済み Skill

### 1. HeroUI Native 公式 Skill（最優先）

| 項目 | 内容 |
|---|---|
| Skill 名 | `heroui-native` |
| 導入コマンド | `npx skills add heroui-inc/heroui` |
| 取得元 | `heroui-inc/heroui`（GitHub 公式） |
| バージョン | ドキュメント参照先 **v1.0.3** / プロジェクト導入版 `heroui-native@1.0.6` |
| 配置 | `.agents/skills/heroui-native`（universal + Claude Code symlink） |
| 使用目的 | コンポーネント実在確認、slot 構造・props・variant の確認、テーマ変数の取得 |
| 使用者 | **Claude（設計）／ Codex（実装）両方** |

`curl -fsSL https://heroui.com/install | bash -s heroui-native` も存在を確認したが、`npx skills add` が Claude Code / Codex 双方へ同時配置できるため後者を採用した。

**同梱された `heroui-react` は Web 版のため使用しない。** 設計・実装のいずれでも参照禁止とする（`docs/design/codex-execution-rules.md` に明記）。

#### 本 Skill で確認した事実（設計の前提）

`node .agents/skills/heroui-native/scripts/list_components.mjs` の実行結果より、**v1.0.3 時点で 39 コンポーネント**が存在する。

```
Accordion, Alert, Avatar, BottomSheet, Button, Card,
Checkbox, Chip, CloseButton, ControlField, Description, Dialog,
FieldError, Input, InputGroup, InputOTP, Label, LinkButton,
ListGroup, Menu, Popover, PressableFeedback, RadioGroup, ScrollShadow,
SearchField, Select, Separator, Skeleton, SkeletonGroup, Slider,
Spinner, Surface, Switch, Tabs, TagGroup, Text,
TextArea, TextField, Toast
```

**設計上とくに重要な確認事項:**

1. **`Progress` / `ProgressBar` は存在しない。** 録音の経過、文字起こしの進捗、アップロード進捗などの「決定的進捗」表示は Memora 固有の独自コンポーネントとして設計する必要がある。`Slider` は入力用であり進捗表示に流用しない。
2. **`Card` は compound component。** slot は `Card.Header` / `Card.Title` / `Card.Description` / `Card.Body` / `Card.Footer`。内部の余白とタイポグラフィは HeroUI 側が管理するため、root だけ使って中身を自前で組むと破綻する。
3. **テーマ変数は OKLCH 形式**（`oklch(0.9702 0 0)` 等）。HSL ではない。`surface-shadow` も定義されているが、本プロジェクトでは影を使わない方針のため無効化する。
4. `ScrollShadow` が存在する。Apple の「hard divider ではなく scroll edge effect」原則に沿う実装が可能。

参照スクリプト:
```bash
node .agents/skills/heroui-native/scripts/list_components.mjs
node .agents/skills/heroui-native/scripts/get_component_docs.mjs Card
node .agents/skills/heroui-native/scripts/get_theme.mjs
```

### 2. Expo 公式 Skill

| 項目 | 内容 |
|---|---|
| 導入コマンド | `npx skills add expo/skills` |
| 取得元 | `expo/skills`（GitHub 公式） |
| 配置 | `.agents/skills/expo-*` |
| 使用目的 | Expo Router の構造、プロジェクト構成、dev client の前提確認 |
| 使用者 | Claude（設計）／ Codex（実装）両方 |

`/plugin install expo@claude-plugins-official` は本環境で利用できなかったため、`npx skills add expo/skills` を採用した。

**HeroUI Native と競合する UI ライブラリは導入していない。**

### 3. 既存の設計系 Skill（本作業以前から導入済み・継続使用）

| Skill | 使用目的 | 使用者 |
|---|---|---|
| `minimalist-ui` | フラット・低彩度・タイポグラフィのコントラスト。Memora のブランド方向と一致 | Claude |
| `apple-design` | 流体インターフェース原則、spring の実装値（damping / response）、材質と階層 | Claude / Codex |
| `emil-design-eng` | UI 品質の原則、押下フィードバック、イージング選択 | Claude / Codex |
| `find-animation-opportunities` | モーションを「入れるべき箇所／入れるべきでない箇所」の切り分け | Claude |
| `review-animations` | モーション品質の評価基準 | Claude |
| `ios-accessibility` | VoiceOver、Dynamic Type、フォーカス管理 | Claude / Codex |
| `redesign-existing-projects` | 既存プロジェクトの監査手順 | Claude |
| `high-end-visual-design` | **部分採用**。工芸的技法（入れ子の縁、同心円の角丸、ヘアライン）のみ | Claude |

## 導入しなかった候補と理由

| 候補 | 理由 |
|---|---|
| `heroui-react` | **HeroUI Web 版。** React Native では動作せず、API も異なる。同梱されたが使用禁止とする |
| `gpt-taste` | GSAP ScrollTrigger・AIDA ページ構造前提の**ランディングページ向け**。RN アプリには不適 |
| `design-taste-frontend` | 同上。ランディング／ポートフォリオ向け |
| `imagegen-*` / `brandkit` | 画像生成のみでコードを出さない。本フェーズの成果物と合致しない |
| `industrial-brutalist-ui` | Memora の低彩度・静かなブランドと方向性が正反対 |
| `stitch-design-taste` | Google Stitch 向けの DESIGN.md 生成。本プロジェクトの設計プロセスと重複 |
| 追加のアクセシビリティ監査 Skill | 既存の `ios-accessibility` で足りると判断。無条件の追加は避ける方針に従った |

`high-end-visual-design` は**全面採用しない**。巨大余白（py-24〜py-40 相当）、非対称ベントーグリッド、巨大タイポグラフィ、hover 前提の演出はマーケティングサイト向けの作法であり、Memora のような情報密度と走査性が重要な実用アプリに適用すると可用性を損なう。工芸的技法（拡散した影の代わりのヘアライン、同心円の角丸、押下時 scale）のみを採る。

## 設計フェーズでの参照順序

1. `heroui-native` Skill — **API の実在確認は必ずここで行う。記憶で推測しない**
2. Expo 公式 Skill — Router / プロジェクト構成
3. `minimalist-ui` / `apple-design` / `emil-design-eng` — 視覚とモーションの判断
4. `ios-accessibility` — アクセシビリティ要件
