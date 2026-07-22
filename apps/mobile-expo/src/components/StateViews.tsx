import { AppIcon } from './AppIcon';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, textStyles } from '../design/tokens';

export function LoadingState({ label = '読み込み中' }: { label?: string }) {
  return (
    <View style={styles.stateCard}>
      <View style={styles.iconWrap}>
        <AppIcon color={colors.accent} name="sync-outline" size={20} />
      </View>
      <Text style={styles.title}>{label}</Text>
      <Text style={styles.body}>Native bridge へ差し替えても同じ状態表示を使います。</Text>
    </View>
  );
}

export function EmptyState({
  title,
  body,
  actionLabel,
  onAction,
}: {
  title: string;
  body: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <View style={styles.stateCard}>
      <View style={styles.iconWrap}>
        <AppIcon color={colors.accent} name="file-tray-outline" size={20} />
      </View>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.body}>{body}</Text>
      {actionLabel && onAction ? (
        <Pressable
          accessibilityLabel={actionLabel}
          accessibilityRole="button"
          onPress={onAction}
          style={({ pressed }) => [
            styles.ctaButton,
            pressed && styles.retryButtonPressed,
          ]}
        >
          <Text style={styles.ctaButtonText}>{actionLabel}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <View style={[styles.stateCard, styles.errorCard]}>
      <View style={[styles.iconWrap, styles.errorIcon]}>
        <AppIcon color={colors.danger} name="warning-outline" size={20} />
      </View>
      <Text style={styles.title}>読み込みに失敗しました</Text>
      <Text style={styles.body}>{message}</Text>
      {onRetry ? <Pressable accessibilityLabel="ファイルを再読み込み" accessibilityRole="button" onPress={onRetry} style={({ pressed }) => [styles.retryButton, pressed && styles.retryButtonPressed]}><Text style={styles.retryButtonText}>再試行</Text></Pressable> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  stateCard: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.lg,
    borderWidth: 1,
    gap: spacing.sm,
    padding: spacing.xl,
  },
  errorCard: {
    borderColor: colors.dangerSoft,
  },
  iconWrap: {
    alignItems: 'center',
    backgroundColor: colors.accentSoft,
    borderRadius: radius.pill,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  errorIcon: {
    backgroundColor: colors.dangerSoft,
  },
  title: {
    color: colors.text,
    marginTop: spacing.sm,
    ...textStyles.callout,
  },
  body: {
    color: colors.textSecondary,
    textAlign: 'center',
    ...textStyles.footnote,
  },
  retryButton: { alignItems: 'center', backgroundColor: colors.text, borderRadius: radius.md, marginTop: spacing.sm, minWidth: 112, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  retryButtonPressed: { opacity: 0.78, transform: [{ scale: 0.98 }] },
  retryButtonText: { color: colors.surface, ...textStyles.footnoteBold },
  ctaButton: { alignItems: 'center', backgroundColor: colors.accent, borderRadius: radius.md, marginTop: spacing.md, minWidth: 160, paddingHorizontal: spacing.lg, paddingVertical: spacing.md },
  ctaButtonText: { color: colors.surface, ...textStyles.footnoteBold },
});
