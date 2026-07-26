# Memora 画面一覧

作成日: 2026-07-26
前提: `docs/design/information-architecture.md`, `docs/design/navigation.md`

## 一覧

| # | 画面 | ルート | 種別 | 詳細仕様 |
|---|---|---|---|---|
| 1 | オンボーディング | `onboarding` | full screen modal | — |
| 2 | サインイン | `auth` | full screen modal | — |
| 3 | 権限設定 | `onboarding/permission` | full screen modal | — |
| 4 | ホーム | `(tabs)/index` | tab | `screens/home.md` |
| 5 | ライブラリ | `(tabs)/library` | tab | `screens/library.md` |
| 6 | タスク | `(tabs)/tasks` | tab | `screens/tasks.md` |
| 7 | 設定 | `(tabs)/settings` | tab | `screens/settings.md` |
| 8 | 録音セットアップ | `record` | full screen modal | `screens/recording-setup.md` |
| 9 | 録音中 | `record`（状態） | full screen modal | `screens/active-recording.md` |
| 10 | 処理中 | グローバル + `meeting/[id]` | 状態 | `screens/processing.md` |
| 11 | 会議詳細 | `meeting/[id]` | stack card | `screens/meeting-detail.md` |
| 12 | 文字起こし | `meeting/[id]`（タブ） | 画面内タブ | `screens/transcript.md` |
| 13 | 要約 | `meeting/[id]`（タブ） | 画面内タブ | `screens/summary.md` |
| 14 | プロジェクト詳細 | `project/[id]` | stack card | `screens/projects.md` |
| 15 | タスク詳細 | `task/[id]` | stack card | — |
| 16 | 検索 | `search` | modal | — |
| 17 | サブスクリプション | `subscription` | modal | — |
| 18 | AI 処理の設定 | `settings/ai` | stack card | — |
| 19 | 保存とデータ | `settings/storage` | stack card | — |

## 廃止する画面

| 旧 | 理由 |
|---|---|
| `(tabs)/ask-ai` | 文脈のない AI 質問は使いにくい。会議詳細内の Bottom Sheet へ移設（監査 C-2） |
| `file/[id]` | File 概念廃止。`meeting/[id]` へ |
| `preview` | 開発用。ビルド構成で分離 |
| `dev-fonts` | 開発用。ビルド構成で分離 |

## 追加する画面

| 新規 | 理由 |
|---|---|
| ライブラリ | 会議の探索性確保（監査 C-2, M-3） |
| 録音セットアップ / 録音中 | 録音を一級市民に（監査 C-1） |
| プロジェクト詳細 | Project 概念の可視化（監査 C-3） |
| タスク詳細 | 出典会議への導線（監査 C-3） |
| 検索 | 独立した探索導線（監査 M-3） |
| 権限設定 | 権限拒否状態の設計（監査 M-4） |

---

## 各画面の定義

### 1. オンボーディング

- **Purpose**: Memora が何をするアプリかを理解させ、最初の録音まで導く
- **Entry**: 初回起動
- **Exit**: サインイン、またはスキップしてホーム
- **Primary action**: 「はじめる」
- **Secondary**: スキップ
- **情報階層**: 価値の提示 → 3ステップの説明 → CTA
- **HeroUI**: `Surface`, `Text`, `Description`, `Button`
- **Custom**: なし
- **States**: 通常のみ
- **A11y**: 各ページに見出しレベルを設定。スキップは常に到達可能
- **Analytics**: `onboarding_viewed`, `onboarding_completed`, `onboarding_skipped`
- **受け入れ条件**: 3画面以内で完結する。スキップしてもアプリが使える

### 2. サインイン

- **Purpose**: Google / Apple でのログイン
- **Entry**: オンボーディング後、設定から
- **Exit**: ホーム
- **Primary action**: Apple でサインイン / Google でサインイン
- **Secondary**: メールで続ける、あとで
- **HeroUI**: `Button`, `TextField`, `Input`, `InputOTP`, `FieldError`, `Description`
- **States**: 通常 / 送信中 / 失敗 / オフライン
- **A11y**: OTP 入力は1桁ずつ読み上げられること
- **Analytics**: `signin_started`, `signin_completed`, `signin_failed`
- **受け入れ条件**: OTP は貼り付けで一括入力できる

### 3. 権限設定

- **Purpose**: マイク権限の必要性を説明し取得する
- **Entry**: オンボーディング、録音セットアップで未許可の場合
- **Exit**: 録音セットアップ
- **Primary action**: 「マイクを許可」
- **Secondary**: 設定アプリを開く（拒否済みの場合）
- **HeroUI**: `Surface`, `Text`, `Description`, `Button`, `Alert`
- **States**: 未要求 / 拒否済み
- **A11y**: 拒否済み時の復帰手順を読み上げで理解できること
- **受け入れ条件**: 拒否済みでも設定アプリへ誘導できる

### 4. ホーム → `screens/home.md`

### 5. ライブラリ → `screens/library.md`

### 6. タスク → `screens/tasks.md`

### 7. 設定 → `screens/settings.md`

### 8. 録音セットアップ → `screens/recording-setup.md`

### 9. 録音中 → `screens/active-recording.md`

### 10. 処理中 → `screens/processing.md`

### 11. 会議詳細 → `screens/meeting-detail.md`

### 12. 文字起こし → `screens/transcript.md`

### 13. 要約 → `screens/summary.md`

### 14. プロジェクト詳細 → `screens/projects.md`

### 15. タスク詳細

- **Purpose**: 1件のタスクの確認・編集・完了
- **Entry**: タスクタブ、会議詳細のタスク一覧
- **Exit**: 戻る、出典会議へ
- **Primary action**: 完了にする
- **Secondary**: 編集、期限設定、削除、出典会議を開く
- **情報階層**: タスク内容 → 出典会議 → 期限 → メモ
- **HeroUI**: `Card`, `Checkbox`, `TextArea`, `Button`, `ListGroup`, `Dialog`（削除確認）
- **States**: 通常 / 編集中 / 保存中 / 失敗
- **A11y**: 完了チェックの状態を `accessibilityState` で表現
- **Analytics**: `task_completed`, `task_edited`, `task_source_opened`
- **受け入れ条件**: **出典会議へ1タップで到達できる**（監査 C-3）

### 16. 検索

- **Purpose**: 会議・文字起こし本文・タスクの横断検索
- **Entry**: ライブラリ上部、ホームのヘッダー
- **Exit**: 検索結果から各詳細へ
- **Primary action**: 検索実行
- **Secondary**: 対象の絞り込み
- **情報階層**: 検索欄 → 対象フィルタ → 結果（種別ごとにグループ）
- **HeroUI**: `SearchField`, `TagGroup`, `ListGroup`, `Chip`
- **Custom**: `SearchResultItem`（一致箇所のハイライト）
- **States**: 未入力 / 検索中 / 結果あり / 結果なし / オフライン
- **A11y**: 結果件数を読み上げる。ハイライトは色だけに依存しない
- **Analytics**: `search_performed`, `search_result_opened`, `search_no_result`
- **受け入れ条件**: **検索対象が画面上で明示される**（監査 M-3）

### 17. サブスクリプション

- **Purpose**: プランの確認と変更
- **Entry**: 設定、上限到達時
- **Exit**: 戻る
- **Primary action**: プランを選ぶ
- **HeroUI**: `Card`, `RadioGroup`, `Button`, `Chip`, `Description`
- **States**: 通常 / 処理中 / 失敗
- **A11y**: 現在のプランを `accessibilityState` で明示
- **受け入れ条件**: 現在のプランと制限が明確に分かる

### 18. AI 処理の設定

- **Purpose**: ローカル処理 / クラウド処理の選択、プロバイダ設定
- **Entry**: 設定
- **Primary action**: 処理方式の選択
- **情報階層**: 処理方式 → プロバイダ → API キー → 検証
- **HeroUI**: `ListGroup`, `RadioGroup`, `TextField`, `Switch`, `Alert`, `Button`
- **States**: 通常 / 検証中 / 検証失敗
- **A11y**: 秘匿情報の入力欄は読み上げに注意
- **受け入れ条件**: **ローカルとクラウドの違いがユーザーの言葉で説明されている**

### 19. 保存とデータ

- **Purpose**: 保存先、使用容量、書き出し、削除
- **Entry**: 設定
- **HeroUI**: `ListGroup`, `Button`, `Dialog`, `Alert`
- **Custom**: `ProgressBar`（容量表示）
- **States**: 通常 / 計算中 / 削除確認
- **受け入れ条件**: 破壊的操作は必ず `Dialog` で確認する
