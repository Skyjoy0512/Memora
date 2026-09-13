import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import { colors, spacing, textStyles } from '../design/tokens';

/**
 * Open Design v2 のボタン群。
 *
 * heroui-native の Button は使わない。hover 色を CSS の `color-mix(in oklab, ...)`
 * から取るのに、同ライブラリ同梱の colorKit がその文字列を解釈できず、描画のたびに
 * `[colorKit.RGB] ...` を console.error に出す（web で確認）。見た目もこちらで
 * 全て上書きしていたため、素の Pressable に置き換えている。
 */

type BaseProps = {
  accessibilityLabel: string;
  onPress: () => void;
  isDisabled?: boolean;
  style?: StyleProp<ViewStyle>;
};

/** 44pt のアイコンのみのボタン（ヘッダー・ツールバー用）。 */
export function IconButton({
  accessibilityLabel,
  children,
  isDisabled,
  onPress,
  style,
}: BaseProps & { children: ReactNode }) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      accessibilityState={{ disabled: Boolean(isDisabled) }}
      disabled={isDisabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.iconButton,
        style,
        isDisabled && styles.disabled,
        pressed && !isDisabled && styles.pressed,
      ]}
    >
      {children}
    </Pressable>
  );
}

/** 黒地のプライマリ操作。 */
export function PrimaryAction({
  accessibilityLabel,
  isDisabled,
  label,
  onPress,
  style,
}: BaseProps & { label: string }) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      accessibilityState={{ disabled: Boolean(isDisabled) }}
      disabled={isDisabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.primary,
        style,
        isDisabled && styles.disabled,
        pressed && !isDisabled && styles.pressed,
      ]}
    >
      <Text style={styles.primaryLabel}>{label}</Text>
    </Pressable>
  );
}

/** 枠線のみの補助操作（`.secondary-button`）。 */
export function SecondaryAction({
  accessibilityLabel,
  isDisabled,
  label,
  onPress,
  style,
}: BaseProps & { label: string }) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      accessibilityState={{ disabled: Boolean(isDisabled) }}
      disabled={isDisabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.secondary,
        style,
        isDisabled && styles.disabled,
        pressed && !isDisabled && styles.secondaryPressed,
      ]}
    >
      <Text style={styles.secondaryLabel}>{label}</Text>
    </Pressable>
  );
}

/** シート内の行（左にアイコン、右に補足）。 */
export function SheetAction({
  accessibilityLabel,
  icon,
  isDestructive,
  label,
  onPress,
  trailing,
}: BaseProps & {
  icon?: ReactNode;
  isDestructive?: boolean;
  label: string;
  trailing?: ReactNode;
}) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.sheetAction, pressed && styles.sheetActionPressed]}
    >
      {icon}
      <View style={styles.sheetActionBody}>
        <Text style={[styles.sheetActionLabel, isDestructive && styles.destructiveLabel]}>
          {label}
        </Text>
      </View>
      {trailing}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  iconButton: {
    alignItems: 'center',
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  pressed: { opacity: 0.62 },
  disabled: { opacity: 0.38 },

  primary: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderColor: colors.accent,
    borderRadius: 0,
    borderWidth: 1,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: spacing.lg,
  },
  primaryLabel: { color: colors.textInverse, ...textStyles.footnoteBold },

  secondary: {
    alignItems: 'center',
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: spacing.md,
  },
  secondaryPressed: { backgroundColor: colors.surfaceAlt },
  secondaryLabel: { color: colors.text, ...textStyles.footnoteBold },

  sheetAction: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    minHeight: 44,
    paddingVertical: spacing.xs,
    width: '100%',
  },
  sheetActionPressed: { backgroundColor: colors.surfaceAlt },
  sheetActionBody: { flex: 1, minWidth: 0 },
  sheetActionLabel: { color: colors.text, ...textStyles.footnote },
  destructiveLabel: { color: colors.danger },
});
