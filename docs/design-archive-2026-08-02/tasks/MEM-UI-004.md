# MEM-UI-004: PR #153のUI差分分離

## Objective

33コミット・93ファイルに跨るPR #153から、再利用可能なHeroUI / Uniwind / UI変更だけを小さなPRへ分離する。

## Scope

- PR #151 / #152、ツール、設計コミットを除外する
- HeroUI導入、テーマ、共通コンポーネント、画面移行を依存順に分類する
- 既にmainへ入った変更との重複を除く
- 1 PR = 1目的になる分割表を作る

## 推奨分割

1. package / Provider / theme基盤
2. 共通コンポーネント
3. Home / Tasks / AI
4. Settings / Auth / Capture
5. File Detail
6. Motion / QA

## Acceptance criteria

1. STT変更を含まない
2. 各PRが独立してtypecheck・web exportできる
3. 新しいNativeTabs設計と衝突する旧TabBar変更を除外する
4. 同じHeroUI移行を再実装しない
