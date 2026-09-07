import { Pressable, StyleSheet, Text, View } from 'react-native';
import { AppIcon } from './AppIcon';
import { colors, shadow, spacing, textStyles } from '../design/tokens';

/** `.detail-ask-button` の実寸。呼び出し側の下部インセット計算に使う。 */
export const ASK_ENTRY_BAR_HEIGHT = 48;

type Props = {
  onPress: () => void;
  label?: string;
  accessibilityLabel?: string;
};

/**
 * Open Design v2 の `.floating-ask-bar` / `.detail-ask-button`。
 * 一覧と詳細に常設していた入力欄をやめ、「質問の入口」だけを浮かせる。
 * 実際の入力は Ask AI 画面が持つ（コンテンツを遮らないための構造）。
 */
export function AskEntryBar({
  onPress,
  label = 'Ask AIに質問',
  accessibilityLabel = '記録についてAsk AIで質問',
}: Props) {
  return (
    <View pointerEvents="box-none" style={styles.bar}>
      <Pressable
        accessibilityLabel={accessibilityLabel}
        accessibilityRole="button"
        onPress={onPress}
        style={({ pressed }) => [styles.button, pressed && styles.pressed]}
      >
        <Text numberOfLines={1} style={styles.placeholder}>
          {label}
        </Text>
        <AppIcon color={colors.text} name="chevron-forward" size={20} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  button: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    justifyContent: 'space-between',
    minHeight: ASK_ENTRY_BAR_HEIGHT,
    paddingHorizontal: spacing.sm,
    ...shadow.floating,
  },
  pressed: {
    backgroundColor: colors.surfaceAlt,
    borderColor: colors.text,
  },
  placeholder: {
    color: colors.textSecondary,
    flexShrink: 1,
    ...textStyles.footnote,
  },
});
