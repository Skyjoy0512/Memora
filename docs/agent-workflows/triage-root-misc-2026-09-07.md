# ルート雑多ファイル・トリアージ報告（2026-09-07）

担当: 読み取り専用トリアージ（実行: ls / rg / git log / git ls-files / head / stat / unzip -l のみ）
状態: 調査完了・変更なし（本ファイルの新規作成のみ）

---

## A. リポジトリ直下の untracked ファイル／ディレクトリの切り分け

### 共通の前提（検証済み）

- 対象 8 件はすべて `git ls-files` 空・`git log --all --oneline -- <path>` 空＝**過去に git 管理されたことがない**（現行ブランチ chore/opencode-20260816 @ 115a7fec でも untracked）。
- `.gitignore` にも一致パターンなし（`git check-ignore` で非無視を確認）。

### 分類表

| ファイル/ディレクトリ | 正体 | 判定 | 根拠 | 提案 |
|---|---|---|---|---|
| `PROJECT_SPEC.md` (24,064 B, 08-30 17:30) | 「Zoom Meeting Notes Chrome Extension」製品/技術仕様書 v0.1（Chrome MV3＋GAS＋ブラウザ内 Whisper＋Chrome Built-in AI、法人 Google Workspace 向け） | ③別案件・誤置 | タイトル・対象が Memora（iOS/RN 議事録アプリ）と不一致。Memora 固有語（mobile-expo / SwiftUI / 録音等）への言及ゼロ。参照先 `docs/CORPORATE_VALIDATION.md` 等は本リポジトリに存在しない | 別案件リポジトリ/フォルダへ移動。Memora 内で進める場合は docs/online-meeting-capture-plan.md（Mode A）と統合する整理が必要 |
| `TASKS.md` (7,347 B, 08-30 17:30) | 同案件の並列タスク計画（TASK-001〜605、Milestone 0〜3: GAS 法人 PoC / Whisper ベンチ / Chrome AI PoC → UI/キャプチャ/GAS 保存 → E2E/監査） | ③別案件・誤置 | 内容がすべて上記 Chrome 拡張案件。Memora のタスク体系（GitHub Issue/PR・docs/design/implementation-plan.md）と無関係 | 同上（PROJECT_SPEC.md とセットで移動） |
| `CODEX_BOOTSTRAP_PROMPT.md` (2,670 B, 08-30 17:30) | 同案件の Codex=PM 起動プロンプト（MV3・Zoom Web only・tabCapture 等の制約を規定） | ③別案件・誤置 | 上記 2 点と同一の制約群・用語。`tasks/` ディレクトリも本リポジトリに存在しない | 同上（セットで移動） |
| `AGENTS.md` (5,533 B, 08-30 17:30) | 同案件バンドル同梱の「Codex/OpenCode 運用モデル」テンプレ（worktree 例 `wt-gas / TASK-401-gas-core`、GAS export 契約を含む） | ③別案件由来 かつ ②要即時判断 | zip 内と同サイズで同梱物。Memora 固有の運用正本は追跡済み `docs/agent-operating-model.md`（Sol/Luna/OpenCode/Claude、OpenCode=DeepSeek 限定）であり、本ファイルの内容と競合。root に置くと各エージェントツールが自動適用するため誤った運用モデルが効く | root の AGENTS.md は docs/agent-operating-model.md 準拠の Memora 版に置換するか削除。別案件分は zoom パッケージ側で管理 |
| `zoom-meeting-notes-spec.zip` (16,884 B, 08-30 17:30) | 上記 4 ファイルを格納する元アーカイブ（`unzip -l` のみ実施: PROJECT_SPEC.md 24,064 / AGENTS.md 5,533 / TASKS.md 7,347 / CODEX_BOOTSTRAP_PROMPT.md 2,670 = 08-30 08:09 作成。展開物と全サイズ一致） | ③別案件の成果物（誤置） | リポジトリ外の展開元（DevSSD Projects / Documents/Codex を浅く探索）に見当たらず、Memora 直下にだけ存在。Memora の README/docs からも未参照 | 別案件フォルダ/リポジトリへ移動して原本を 1 箇所に。Memora リポジトリには不要 |
| `Memora-DesignSystem-v07.html` (1,266 B, 08-18 09:29) | v0.7 デザインシステムのプレビュー起動スタブ（`./.ds-preview-tmp/v07.html` へ meta refresh） | ④削除候補（破損スタブ） | リダイレクト先 `.ds-preview-tmp/` がリポジトリ内に存在せず（`ls` で確認）、リンク切れ。正本は docs/design-system/（生成 index.html）側。2026-08-18 前後のブランド/ロゴ探索で作られた一時導線と推定 | 削除、または実体（.ds-preview-tmp/v07.html）が残っている作業スペースとセットで退避 |
| `docs/design-system/` (22 エントリ, 08-19〜20) | Memora デザインシステムの**生成ツール一式**（正本 `_tokens.py` ＋ build.py ＋ `_sections_a〜j.py` / `_icons.py` / `_wave.py` / `_anatomy.py` / `_css.py` ＋ 生成物 index.html 359,871 B・tokens/） | ①Memora 関連・作業継続に必要 ＋ ②git 管理判断が必要 | README が「値の正本は `_tokens.py`・index.html は生成物で手編集禁止」と明記し、唯一のトークン定義元と位置づけ。にもかかわらずディレクトリ全体が untracked（docs/design/ は 8 ファイル、docs/design-archive-2026-08-02/ は 83 ファイル追跡済みなのに本ディレクトリのみ 0 追跡） | 追跡方針を決めて `git add`（推奨: ソース `_*.py`/`build.py`/README を管理、生成物 index.html/tokens/ は再生成可なので運用ルールと併せて管理対象を明示）。放置はトークン正本の喪失リスク |
| `docs/agent-workflows/` (8 エントリ, 08-03〜08-30) | エージェント報告の**作業ツリー常置ファイル群**（opencode-handoff-2026-08-16 系、opencode-followup-2026-08-16、codex-overnight-2026-08-15、opendesign-v2-handoff-2026-08-24、claude-review-opencode/runs/） | ②Memora 関連（git 非追跡の既存運用） | 既存報告（opencode-handoff-2026-08-16-result.md「参照出力」）に「docs/agent-workflows/ は git 管理外の作業ツリー常置ファイル」と明記され、非追跡が意図的運用 | 現行慣行どおり非追跡で維持（重要報告のみ厳選コミットするなら別途判断）。本トリアージ報告もこの慣行に従いここへ配置 |

### 補足（関連性の確認結果）

- ルート 4 文書（PROJECT_SPEC / TASKS / CODEX_BOOTSTRAP / AGENTS）は zoom zip の展開物で、Memora のドキュメント群（docs/Memora_*.md・device-integration-plan.md・online-meeting-capture-plan.md・docs/design/）とは**別の案件バンドル**。
- 唯一の接点: 追跡済み `docs/online-meeting-capture-plan.md`（2026-07-13）が「Mode A = Chrome 拡張による会議録音」を将来経路として挙げ「Chrome 拡張 target / package は存在しない」と記載。ただし zoom 仕様は専用 GAS Web App・Drive/Docs 保存・複数 Google アカウント等を独自に持つ自己完結の法人向け製品仕様で、Memora の既存 product path（AudioFile/Transcript）合流方針とも別体系。＝「Memora が将来作る Chrome 拡張」の下書きというより**別プロジェクトの企画書**として扱うのが妥当。
- ルートに展開された 4 文書は Memora の「仕様の正本」とは呼べない。Memora の仕様正本は README.md / CLAUDE.md / docs/ 配下（例: docs/agent-operating-model.md、ADR-001〜004）であり、これらは追跡済み。

---

## B. PlayerBar hitSlop フォローアップ（2026-08-16）の反映状況

判定: **修正1・修正2・確認3（報告書への追記）いずれも未反映**。

### 修正1（trackWrap 縦 hitSlop）— 未反映

- 現行 `apps/mobile-expo/src/components/PlayerBar.tsx:49` のシーク用 Pressable（trackWrap）に **hitSlop なし**。スタイルは `height: 12` のまま → 実効タップ領域は縦 12pt（44pt 未満）。
- `git log --all -p -- PlayerBar.tsx` の全履歴を確認したが、**trackWrap へ hitSlop を追加したコミットは存在しない**。HEAD（115a7fec）時点でも同値。

### 修正2（rateButton 横 hitSlop）— 未反映

- 現行 `apps/mobile-expo/src/components/PlayerBar.tsx:44` は f94ca98b 当時と同一の `hitSlop={{ bottom: 10, left: 2, right: 2, top: 10 }}`。`left/right` は 2 のまま。
- 実効サイズ（フォローアップ指示の計算式）: 縦 = 4(paddingVertical)+16(lineHeight captionBold)+4+10+10 = **44pt ✓** / 横 = テキスト「1x」約14pt+8+8+2+2 = **約34pt ✗**（44pt 未満のまま）。

### 確認3（7 箇所の実効タップ領域計算表の報告）— 未反映

- 追記先のはずの `docs/agent-workflows/opencode-handoff-2026-08-16-result.md` は mtime **2026-08-16 09:45**（フォローアップ指示ファイルの 17:07 より前）のまま。見出しはタスクA〜E＋検証まとめ＋判断保留＋参照出力で終わっており、**修正1・2 の設定値/根拠・確認3 の 7 箇所表・コミットハッシュの追記なし**。
- 7 箇所の hitSlop 自体は現コードに残存（rg 確認）:
  - CaptureFlowProvider.tsx:494 generateBack `2`（40pt → 実効 44）
  - CaptureFlowProvider.tsx:755/774 islandRecording・islandGeneration `{top:4,bottom:4}`（36pt → 実効 44）
  - CaptureFlowProvider.tsx:806 RoundIcon 小 `size==="small" ? 2 : 0`（40pt → 実効 44）
  - AuthFlowScreen.tsx:506 back `2`（40pt → 実効 44）
  - FileDetailScreen.tsx:799 写真を削除 `12`（20pt → 実効 44）
  - PlayerBar.tsx:44 rateButton（上記のとおり**横のみ不足**）
- 補足: フォローアップで「対象外→対象」に訂正された trackWrap は未対応のまま。作業ツリーの PlayerBar.tsx 差分は hitSlop と無関係（borderRadius の token 化・fonts.mono 適用など別タスクのトークン整理）。
- 参照: フォローアップ指示は「同じブランチ chore/opencode-20260816 に積む」だったが、その後の同ブランチのコミットは 115a7fec（style 置換）のみで hitSlop 修正は積まれていない。

---

## C. その他気づき

1. **docs/design-system/ が完全に git 未管理**なのが最大のリスク。値の正本（_tokens.py）と生成物（index.html 359 KB 等）が揃って untracked で、ディスク障害や誤削除でトークン体系を失い得る。docs/design/（8 件）や docs/design-archive-2026-08-02/（83 件）は追跡済みで、ここだけ非追跡なのは意図的でない可能性が高い。
2. **zoom-meeting-notes-spec.zip の本来の置き場所が不明**（DevSSD Projects / Documents/Codex の浅い探索では同一 zip や CODEX_BOOTSTRAP_PROMPT.md の複製なし）。ルートへの展開日時は 2026-08-30 17:30 で 4 ファイル一斉。ユーザーに元の意図（別案件の起動用か、どこへ移すか）の確認を推奨。
3. **root AGENTS.md は「あるだけで効く」**ため放置が危険。未追跡でもリポジトリルートにある限りエージェント運用に適用され、Memora の正本運用（docs/agent-operating-model.md）と二重化・競合する。即時の置換 or 削除判断を推奨。
4. 8/16 フォローアップの残作業（修正1・2、確認3 表の報告）は実機 QA 担当・次の実装担当へ引き継ぎが必要な状態。
5. 本報告は既存慣行に従い docs/agent-workflows/（git 管理外の作業ツリー常置ファイル群）へ配置した。
