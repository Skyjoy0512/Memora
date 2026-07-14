import { LiquidGlassView, isLiquidGlassSupported } from '@callstack/liquid-glass';
import type { ReactNode } from 'react';
import { StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { colors, radius, spacing } from '../design/tokens';

type SheetCardProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
};

export function SheetCard({ children, style }: SheetCardProps) {
  return (
    <LiquidGlassView
      colorScheme="light"
      effect="regular"
      tintColor="rgba(255,255,255,0.78)"
      style={[styles.card, !isLiquidGlassSupported && styles.fallback, style]}
    >
      {children}
    </LiquidGlassView>
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
