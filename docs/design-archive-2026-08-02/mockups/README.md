# デザインモックアップ

各 HTML は単一ファイルで完結した、393 × 852 CSS px（iPhone 14 Pro Max）の静的モックアップです。ブラウザで直接開き、`#screen` 要素を切り出して PNG 化してください。外部フォント、画像、CDN、JavaScript は使用していません。

## 対応仕様

| モックアップ | 対応する仕様 |
| --- | --- |
| `home.html` | `docs/design/screens/home.md`、`docs/design/wireframes.md` の「ホーム」 |
| `active-recording.html` | `docs/design/screens/active-recording.md`、`docs/design/wireframes.md` の「録音中」 |
| `meeting-detail-summary.html` | `docs/design/screens/meeting-detail.md`、`docs/design/screens/summary.md`、`docs/design/wireframes.md` の「会議詳細 / 要約タブ」 |
| 全ファイル | `docs/design/design-tokens.md`、`docs/design/design-system.md`、`docs/design/ux-copy.md`、`apps/mobile-expo/src/design/tokens.ts` |

## 再生成・修正手順

1. 対応する画面仕様、ワイヤーフレーム、`ux-copy.md` を読み、表示する状態と文言を確定する。
2. 各 HTML のインライン `<style>` で、`tokens.ts` のライトテーマ実値だけを使って調整する。余白は `3/5/8/13/21/34/55`、角丸は `4/8/13/21/999` に限定する。
3. `#screen` の `width: 393px` と `height: 852px` を維持し、影、グラデーション、外部リソースを追加しない。
4. ブラウザで各ファイルを開き、開発者ツールまたはスクリーンショットツールで `#screen` のみを PNG 化する。
5. 修正後に `git diff --check` と `git status --short` を実行し、意図した差分が `docs/design/mockups/` 内だけであることを確認する。
