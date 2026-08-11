# MEM-UI-003: PR #152の整理

## Objective

RNホストの実SpeechAnalyzer経路を、PR #151のストア接続基盤上で検証・統合できる状態にする。

## Scope

- PR #152のbaseをPR #151の統合結果へ合わせる
- SpeechAnalyzer実装の共有コア移設とRN bridge接続を分離してレビューする
- backend選択、preflight、fallback、diagnosticsを確認する
- 文字起こしコア保護ルールに従ってbuild・test・logを報告する

## Do not change

- UI再設計
- HeroUI移行
- File / Meetingの名称やデータモデル

## Acceptance criteria

1. PR #151との差分だけをレビューできる
2. SpeechAnalyzer不成立時に既存fallbackへ戻る
3. backendとfallback reasonがログで追える
4. shared package testsとRN iOS buildが成功する
5. PRをDraft解除できる
