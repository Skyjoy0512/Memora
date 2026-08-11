# Memora 画面一覧

更新日: 2026-08-02
前提: `information-architecture.md`, `navigation.md`, ADR-001

## 本番ルート

| # | 画面 | ルート | 種別 | 詳細仕様 |
|---|---|---|---|---|
| 1 | ホーム | `(tabs)/index` | NativeTab | `screens/home.md` |
| 2 | タスク | `(tabs)/tasks` | NativeTab | `screens/tasks.md` |
| 3 | AI | `(tabs)/ask-ai` | NativeTab | 既存 `AskAIScreen` を段階改修 |
| 4 | 設定 | `(tabs)/settings` | NativeTab | `screens/settings.md` |
| 5 | File Detail | `file/[id]` | Stack push | `screens/file-detail.md` |
| 6 | 録音セットアップ / 録音中 | `record` | fullScreenModal | `screens/recording-setup.md`, `screens/active-recording.md` |
| 7 | インポート | capture flow | modal | FABメニューから開始 |
| 8 | オンライン会議 | meeting capture flow | modal | FABメニューから開始 |
| 9 | 検索 | `search` | modal | ホームヘッダーから開始 |
| 10 | 認証 | `auth` | fullScreenModal | 既存 `AuthFlowScreen` |

## 固定UI

| UI | 配置 | 責務 |
|---|---|---|
| NativeTabs | `(tabs)/_layout.tsx` | ホーム / タスク / AI / 設定 |
| 中央FAB | NativeTabs上 | 録音 / インポート / オンライン会議の作成メニュー |
| AIComposer | `NativeTabs.BottomAccessory` | 全タブ共通の軽量質問入力 |
| RecordingStatusBar | NativeTabs上 | 録音・処理状態と復帰導線 |

## 開発専用ルート

`preview` と `dev-fonts` は開発用として維持し、本番ビルドでは到達不能にする。設計資料から削除することと、ソースファイルを即時削除することは同義ではない。

## 旧案

次は2026-07-26午前版の旧案であり、新規実装しない。

- `(tabs)/library`
- `meeting/[id]` への一括改名
- Askタブ廃止
- 独自TabBar

`screens/library.md` と旧wireframeは履歴資料として保持する。
