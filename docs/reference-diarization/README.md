# Speaker Diarization Reference Data

PlaudNote 出力を正解データとして、Memora の FluidAudio 話者分離精度をチューニングする。

## Directory Structure

- `plaud/`: PlaudNote 出力（話者ラベル付きテキスト）— 正解データ
- `memora/`: Memora 出力（話者分離結果）— 比較対象

## How to Use

1. PlaudNote で音声ファイルを文字起こしし、出力を `plaud/` に保存
2. Memora で同一音声ファイルを文字起こしし、結果を `memora/` に保存
3. 両者の話者数・セグメント分割を比較してパラメータを調整

## Naming Convention

ファイル名は音声ファイル名と対応させる:
- `plaud/<audio-filename>.txt`
- `memora/<audio-filename>.segments.txt`

## Parameter Tuning

FluidAudio `OfflineDiarizerConfig` の主要パラメータ:
- `clustering.numSpeakers`: Plaud の話者数で固定（最も効果的）
- `clustering.threshold`: 0.25〜0.60（デフォルト 0.38）
- `clustering.warmStartFa/Fb`: 0.07/0.8（デフォルト）
