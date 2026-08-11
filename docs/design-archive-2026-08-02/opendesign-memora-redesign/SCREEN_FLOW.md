# 画面遷移・情報フロー図

> Memora リデザイン / クリエイティブディレクション成果物
> 更新: 2026-07-14

---

## 全体画面遷移図

```mermaid
graph TD
    A["🏠 ホーム<br/>最近の記録一覧<br/>セグメント: すべて/お気に入り/プロジェクト"] -->|"カードタップ"| B["📄 ファイル詳細<br/>タブ: 概要/文字起こし/メモ/質問<br/>再生バー常時表示"]

    A -->|"FAB → 録音"| C["🎙 録音画面<br/>録音中/タイトル入力/メモ<br/>テンプレート選択/停止"]

    A -->|"タブ"| D["✅ タスク<br/>期限切れ/今日/今後/完了<br/>チェックボックス切替"]

    A -->|"タブ"| E["💬 Ask AI<br/>スコープ切替:全体/プロジェクト/ファイル<br/>会話スレッド/質問入力"]

    A -->|"タブ"| F["⚙ 設定<br/>アカウント/処理/通知<br/>データ/情報/アカウント操作"]

    B -->|"質問タブ"| E
    B -->|"アクション → タスク化"| D
    B -->|"ソースピル タップ"| B2["同ファイル詳細<br/>該当セクションにスクロール"]

    C -->|"停止 → 自動保存"| A
    C -->|"閉じる（バックグラウンド継続）"| A

    E -->|"ソースピル タップ"| B
    E -->|"回答 → タスク化"| D

    F -->|"ログイン"| G["🔐 認証<br/>ようこそ/ログイン/登録<br/>プラン選択"]

    A -->|"検索バー"| A1["🔍 検索結果表示<br/>リアルタイムフィルタ<br/>タイトル/要約/文字起こし横断"]

    classDef home fill:#FAFAF8,stroke:#1A7F6B,stroke-width:2px,color:#1A1C1E
    classDef detail fill:#FFFFFF,stroke:#E2E3E5,stroke-width:1px,color:#1A1C1E
    classDef capture fill:#FFFFFF,stroke:#C62828,stroke-width:2px,color:#1A1C1E
    classDef task fill:#FFFFFF,stroke:#E2E3E5,stroke-width:1px,color:#1A1C1E
    classDef ask fill:#FFFFFF,stroke:#E2E3E5,stroke-width:1px,color:#1A1C1E
    classDef settings fill:#FFFFFF,stroke:#E2E3E5,stroke-width:1px,color:#1A1C1E
    classDef auth fill:#FFFFFF,stroke:#E2E3E5,stroke-width:1px,color:#1A1C1E

    class A,A1 home
    class B,B2 detail
    class C capture
    class D task
    class E ask
    class F settings
    class G auth
```

---

## 主要ユーザーフロー: 録音 → 保存 → 振り返り → 質問

```mermaid
sequenceDiagram
    actor U as ユーザー
    participant H as ホーム
    participant R as 録音画面
    participant B as バックグラウンド処理
    participant D as ファイル詳細
    participant AI as Ask AI
    participant T as タスク

    U->>H: FAB「録音」をタップ
    H->>R: 録音モーダル表示

    Note over U,R: 録音中（経過時間・波形表示）
    U->>R: ひと言メモを入力
    U->>R: タイトルを編集（任意）
    U->>R: 停止ボタンタップ

    R->>B: 録音データ保存 + 文字起こし・要約を開始
    R->>H: 「保存しました」→ ホームに戻る

    Note over H: Dynamic Island Pill に<br/>「文字起こし中…」表示

    B-->>H: 文字起こし完了 → Pill 更新
    B-->>H: 要約完了 → Pill「要約が完成しました」

    U->>H: カードタップ
    H->>D: ファイル詳細表示

    Note over U,D: 概要タブで要約を確認
    Note over U,D: 文字起こしタブで再生・確認

    U->>D: 質問タブをタップ
    D->>AI: スコープ「ファイル」で遷移

    U->>AI: 「決定事項を整理して」と質問
    AI-->>U: 回答 + ソースピル表示

    U->>AI: 回答の「タスク化」をタップ
    AI->>T: アクション項目をタスクに追加

    U->>T: タスク画面で確認・完了チェック
```

---

## 状態遷移図: 録音ライフサイクル

```mermaid
stateDiagram-v2
    [*] --> アイドル: FAB表示「+」

    アイドル --> 権限チェック: 録音タップ
    権限チェック --> 録音中: 権限OK
    権限チェック --> 権限未許可: マイク権限なし
    権限未許可 --> アイドル: 設定アプリで許可→戻る

    録音中 --> 一時停止: 一時停止タップ
    一時停止 --> 録音中: 再開タップ

    録音中 --> 破棄確認: 破棄タップ
    破棄確認 --> アイドル: 破棄確定
    破棄確認 --> 録音中: キャンセル

    録音中 --> 保存中: 停止タップ
    保存中 --> バックグラウンド処理: 保存成功
    保存中 --> 保存失敗: エラー
    保存失敗 --> 保存中: 再試行
    保存失敗 --> アイドル: 破棄

    バックグラウンド処理 --> 文字起こし中: 自動開始
    文字起こし中 --> 要約生成中: 文字起こし完了
    要約生成中 --> 完了: 要約完了
    文字起こし中 --> 失敗: エラー
    要約生成中 --> 失敗: エラー
    失敗 --> 文字起こし中: 再試行（手動）

    完了 --> [*]: ファイル詳細から確認可能
```

---

## ファイル詳細タブ遷移

```mermaid
graph LR
    A["概要<br/>要約/決定事項<br/>次のアクション<br/>参照"] --> B["文字起こし<br/>話者色分け<br/>再生ハイライト<br/>タイムスタンプ"]
    B --> C["メモ<br/>自由記述<br/>写真添付<br/>自動保存"]
    C --> D["質問<br/>ファイルスコープ<br/>質問提案<br/>簡易チャット"]

    A -.->|"アクション項目をチェック"| T["✅ タスク画面に反映"]
    B -.->|"再生位置にスクロール"| B
    D -.->|"ソースピルタップ"| A

    classDef tab fill:#FFFFFF,stroke:#1A7F6B,stroke-width:2px,color:#1A1C1E
    classDef external fill:#FAFAF8,stroke:#E2E3E5,stroke-width:1px,color:#1A1C1E

    class A,B,C,D tab
    class T external
```

---

## データフロー: 画面 ↔ データ層

```mermaid
graph TD
    subgraph Screens["画面層"]
        HS["ホーム"]
        FD["ファイル詳細"]
        AI["Ask AI"]
        TS["タスク"]
        ST["設定"]
        RC["録音"]
    end

    subgraph Hooks["フック層（変更不可）"]
        UF["useAudioFiles"]
        UA["useAudioFile"]
        UP["usePlayback"]
        UT["useTranscriptionTask"]
        UM["useMemoNotes"]
        UC["useCaptureFlow"]
    end

    subgraph Bridge["ネイティブブリッジ層（変更不可）"]
        MN["MemoraNative"]
    end

    subgraph Native["ネイティブ層（変更不可）"]
        SW["SwiftData/Repository"]
        STT["STTサービス"]
        AV["AVFoundation録音"]
        KB["Keychain"]
    end

    HS --> UF
    FD --> UA
    FD --> UP
    FD --> UT
    FD --> UM
    AI --> MN
    TS --> MN
    ST --> MN
    RC --> UC

    UF --> MN
    UA --> MN
    UP --> MN
    UT --> MN
    UM --> MN
    UC --> MN

    MN --> SW
    MN --> STT
    MN --> AV
    MN --> KB

    classDef screen fill:#FAFAF8,stroke:#1A7F6B,stroke-width:2px,color:#1A1C1E
    classDef hook fill:#E8F5F1,stroke:#1A7F6B,stroke-width:1px,color:#1A1C1E
    classDef bridge fill:#FFF3E0,stroke:#E65100,stroke-width:1px,color:#1A1C1E
    classDef native fill:#FFEBEE,stroke:#C62828,stroke-width:1px,color:#1A1C1E

    class HS,FD,AI,TS,ST,RC screen
    class UF,UA,UP,UT,UM,UC hook
    class MN bridge
    class SW,STT,AV,KB native
```

---

## 参照ドキュメント

- `SCREEN_SPECS.md` — 各画面の詳細なProps・状態・日本語文言
- `COMPONENT_MAP.md` — コンポーネントのファイル配置と依存関係
- `CODEX_IMPLEMENTATION_PROMPT.md` — 実装順序とフェーズ分け
