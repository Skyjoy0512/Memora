/**
 * NumericText — デザインシステム v0.6 / 数値の等幅規律
 *
 * 「数値・時刻・経過時間・ID・件数は必ず IBM Plex Mono + tabular-nums」
 * というルールを、和欧混在の文字列に対して安全に適用するためのもの。
 *
 * 文字列まるごとに mono を掛けると、Plex Mono は CJK グリフを持たないため
 * 和文だけシステムフォントに落ちて字面が割れる。そこで数字の連なりだけを
 * ネストした Text で mono に差し替える。
 *
 *   <NumericText style={styles.meta}>8月15日 20:04 · 01:38</NumericText>
 *   →  8 月 15 日 20:04 · 01:38   （数字部分だけ Plex Mono / tabular）
 *
 * 純粋に数値だけの表示（再生位置・録音経過など）にはこれを使わず、
 * スタイルへ直接 `...fonts.mono.regular` を足すほうが安い。
 * 英数字が混じる ID（"a1b2" など）も同様に直接 mono を当てること。
 * この分割は数字だけを拾うので、ID に使うと "a[1]b[2]" のように割れる。
 *
 * ネストした Text は VoiceOver では 1 つの読み上げ要素として扱われるので、
 * アクセシビリティ上の分断は起きない。
 */

import { Text, type StyleProp, type TextProps, type TextStyle } from 'react-native';
import { fonts } from '../design/tokens';

/**
 * 数字から始まり、数字・区切り記号が続く連なり。
 * 12:04 / 8,470 / 0.91 / 2026-08-18 / 1.5x をひとまとまりとして拾う。
 * 記号で終わらないよう末尾は数字に固定する（"20:04 ·" の "·" を巻き込まない）。
 */
const NUMERIC_RUN = /(\d[\d.,:\-/]*\d|\d)/g;

type Props = Omit<TextProps, 'children'> & {
  children: string;
  style?: StyleProp<TextStyle>;
  /** 数値部分に追加で当てるスタイル（色を変えたい場合など） */
  numericStyle?: StyleProp<TextStyle>;
};

export function NumericText({ children, style, numericStyle, ...rest }: Props) {
  const parts = children.split(NUMERIC_RUN);

  return (
    <Text style={style} {...rest}>
      {parts.map((part, i) =>
        // split はキャプチャグループを奇数インデックスに入れる
        i % 2 === 1 ? (
          <Text key={i} style={[fonts.mono.regular, numericStyle]}>
            {part}
          </Text>
        ) : (
          part
        ),
      )}
    </Text>
  );
}
