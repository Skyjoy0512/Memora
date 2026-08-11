# File Detail

ルート: `app/file/[id].tsx`  
種別: Stack push

## Purpose

1件のファイルについて、要約・文字起こし・メモを読み、必要な補助操作を行う。

## 現在の契約

- タブは Summary / Transcript / Memo を維持する。
- 再生、要約生成、文字起こし進捗、メモ・写真、共有、名称変更、削除の既存ブリッジ契約を壊さない。
- Ask AIはグローバルAIタブとBottomAccessoryから到達できる。File Detail内の質問導線はファイルスコープを渡す。
- `meeting/[id]`への改名やSwiftDataスキーマ変更は行わない。

## 段階移行

1. 既存機能を保ったままHeroUI compound slotsへ移す。
2. 固定Player / AI導線の実測高をスクロール余白へ反映する。
3. Transcriptの準備中・進捗・失敗・再試行を整理する。
4. Summary / Memoの情報階層とアクセシビリティを揃える。

## Acceptance criteria

- 既存のファイル一覧から同じIDで開ける。
- Summary / Transcript / Memoの保存・再生契約が回帰しない。
- スクロール末尾がPlayer、AIComposer、NativeTabsに隠れない。
- Dynamic Type最大、VoiceOver、Dark Modeで主要操作へ到達できる。
