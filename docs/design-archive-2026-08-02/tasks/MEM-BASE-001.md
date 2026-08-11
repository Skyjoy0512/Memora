# MEM-BASE-001: Expo Doctor既存基準線の整理

状態: 未着手

## Objective

既存mainで再現するExpo Doctor 16/20の4分類を、MEM-UI-002から分離して再現・帰属・修正方針まで確定する。

## Scope

- `expo-constants` / `expo-linking`の直接依存不足
- CocoaPods環境
- native config sync
- Expo SDK patch mismatch
- 各分類を「修正する問題」または「根拠付きの許容差分」として記録する

## Constraints

- MEM-UI-002のstore fallback差分へ混ぜない
- package、lockfile、Pods、native project、Expo SDKをこの整理PRでは変更しない
- 依存・設定の更新は分類ごとの1目的1PRで行う
- `expo prebuild --clean`は実行しない

## Acceptance criteria

1. Node 22 / npm 10のclean installからExpo Doctor結果を再現できる
2. 4分類それぞれの原因、影響範囲、担当レーン、対応方針が記録される
3. 既存main由来か新規regressionかを比較結果で判定できる
4. 修正が必要な項目は別PRの受け入れ条件と検証手順まで定義される
5. `git diff --check`が成功する

## Verification

```bash
cd apps/mobile-expo
npm ci
npx expo-doctor
npm run typecheck
npx expo export --platform web
cd ios && pod install
cd .. && npm run qa:ios:build
git diff --check
```

CocoaPodsとRN iOS buildはXcodeライセンス受諾済みの環境で実行し、実行できない場合はブロッカーとして記録する。
