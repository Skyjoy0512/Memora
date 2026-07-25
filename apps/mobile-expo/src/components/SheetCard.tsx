import { LiquidGlassView, isLiquidGlassSupported } from '@callstack/liquid-glass';
import { Surface } from 'heroui-native';
import type { ReactNode } from 'react';
import { StyleSheet, type StyleProp, type ViewStyle, useColorScheme } from 'react-native';
import { colors, darkColors, radius, spacing } from '../design/tokens';

type SheetCardProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
};

export function SheetCard({ children, style }: SheetCardProps) {
  const colorScheme = useColorScheme() === 'dark' ? 'dark' : 'light';

  return (
    <Surface asChild variant="transparent">
      <LiquidGlassView
        colorScheme={colorScheme}
        effect="regular"
        tintColor={colorScheme === 'dark' ? darkColors.surface : colors.surface}
        style={[styles.card, !isLiquidGlassSupported && styles.fallback, style]}
      >
        {children}
      </LiquidGlassView>
    </Surface>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: radius.lg,
    marginBottom: spacing.xl,
    marginHorizontal: spacing.md,
    overflow: 'hidden',
  },
  fallback: { backgroundColor: colors.surface },
});
