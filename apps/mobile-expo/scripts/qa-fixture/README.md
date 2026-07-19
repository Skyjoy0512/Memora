# QA フィクスチャハーネス

実データ（実際の会議録音と文字起こし）で RN ホストの表示を検証するための最小ハーネス。
モックデータでは発見できない不具合（#131 / #132 / #133 / #134 はいずれも実データでのみ再現）を
早い段階で捕まえることを目的とする。

## 重要: フィクスチャはリポジトリに置かない

実会議の音声・文字起こしには参加者の実名など個人情報が含まれる。
**リポジトリにコミットしないこと**（CI ログにも流れる）。
ローカルの任意ディレクトリに置き、`MEMORA_QA_FIXTURE` で渡す。

## 使い方

```bash
cd apps/mobile-expo/scripts/qa-fixture
MEMORA_QA_FIXTURE=~/Desktop/memora-verify ./smoke.sh
```

フィクスチャのディレクトリ構成:

- 音声ファイル 1つ（`.mp3` または `.m4a`）
- `*transcript.txt` 1つ（任意）— PLAUD 形式 `HH:MM:SS Speaker N` ＋ 本文行

文字起こしを省くと未文字起こし状態で投入されるため、STT の検証対象を作れる。

## 環境変数

| 変数 | 既定 | 用途 |
|---|---|---|
| `MEMORA_QA_FIXTURE` | （必須） | フィクスチャのディレクトリ |
| `MEMORA_QA_SIMULATOR` | `booted` | 対象シミュレータの UDID |
| `MEMORA_QA_BUNDLE_ID` | `com.anonymous.memora-rn` | 対象アプリ |
| `MEMORA_QA_OUT` | `.expo/qa-screenshots` | スクリーンショット出力先 |
| `MEMORA_QA_TITLE` | `【QA】実データフィクスチャ` | 投入するファイル名 |
| `MEMORA_QA_LAUNCH_WAIT` | `25` | 起動後の待ち秒数（Metro バンドル取得ぶん） |
| `MEMORA_QA_DETAIL_WAIT` | `8` | 詳細画面の描画待ち秒数 |

## できること / できないこと

自動化できる: フィクスチャ解析 → 共有 SwiftData への投入 → 起動 → 詳細画面へディープリンク → スクショ収集。

自動化できない: 音が実際に鳴っているか、スクロールの体感、表示の自然さ。
これらは人が確認する。ハーネスは「確認できる状態を作るまで」を担う。

## 前提

- Metro が起動していること（Debug ビルドは JS を Metro から読む）
- 対象アプリがシミュレータにインストール済みであること
