# MEM-UI-001: 検証基準線の復旧

状態: 完了（2026-08-02）

## Objective

clean install後のRN型検査をGitHub CIと同じ結果にし、後続UI変更を評価できる基準線を作る。

## Scope

- Node / npmのバージョンとpackage managerを確認・固定する
- `package.json`と`package-lock.json`の整合を確認する
- React Native、Reicon、Expo modulesの型解決差を特定する
- `npm ci` → `npm run typecheck`を再現可能にする
- CIの`expo-check`が実行しているコマンドとローカル手順を一致させる

## Do not change

- STTコア
- SwiftDataスキーマ
- 画面デザイン
- Expo SDKのメジャー／マイナー世代

## Acceptance criteria

1. cleanな`node_modules`から依存関係を導入できる
2. `npm run typecheck`が成功する
3. 実行したNode/npmバージョンを記録する
4. lockfileに意図しない大規模差分がない
5. `git diff --check`が成功する

## Verification

- Node `v22.23.2` / npm `10.9.8`
- `npm ci` exit 0
- `npm run typecheck` exit 0
- `npx expo export --platform web` exit 0（1565 modules、2.8MB bundle）
- `package.json` / `package-lock.json`へNode 22・npm 10要件を追加
- `.node-version`を追加
