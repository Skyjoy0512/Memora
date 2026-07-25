import { AppIcon } from './AppIcon';
import { StyleSheet, Text, View } from 'react-native';
import { Alert, Description, Spinner, Text as HeroText } from 'heroui-native';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { MotionAppear } from './MotionAppear';
import { MotionPressable } from './MotionPressable';

export function LoadingState({ label = '読み込み中' }: { label?: string }) {
  return (
    <MotionAppear>
      <View style={styles.stateCard}>
        <View style={styles.iconWrap}>
          <Spinner size="sm" />
        </View>
        <HeroText style={styles.title}>{label}</HeroText>
        <Description style={styles.body}>Native bridge へ差し替えても同じ状態表示を使います。</Description>
      </View>
    </MotionAppear>
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
    <MotionAppear>
      <View style={styles.stateCard}>
        <View style={styles.iconWrap}>
          <AppIcon color={colors.accent} name="file-tray-outline" size={20} />
        </View>
        <HeroText style={styles.title}>{title}</HeroText>
        <Description style={styles.body}>{body}</Description>
        {actionLabel && onAction ? (
          <MotionPressable
            accessibilityLabel={actionLabel}
            accessibilityRole="button"
            onPress={onAction}
            style={styles.ctaButton}
          >
            <Text style={styles.ctaButtonText}>{actionLabel}</Text>
          </MotionPressable>
        ) : null}
      </View>
    </MotionAppear>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <MotionAppear>
      <Alert accessibilityRole="alert" status="danger" style={styles.errorAlert}>
        <Alert.Indicator />
        <Alert.Content style={styles.alertContent}>
          <Alert.Title>読み込みに失敗しました</Alert.Title>
          <Alert.Description>{message}</Alert.Description>
          {onRetry ? <MotionPressable accessibilityLabel="ファイルを再読み込み" accessibilityRole="button" onPress={onRetry} style={styles.retryButton}><Text style={styles.retryButtonText}>再試行</Text></MotionPressable> : null}
        </Alert.Content>
      </Alert>
    </MotionAppear>
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
  errorAlert: {
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.xl,
  },
  iconWrap: {
    alignItems: 'center',
    backgroundColor: colors.accentSoft,
    borderRadius: radius.pill,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  alertContent: {
    alignItems: 'center',
    gap: spacing.sm,
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
  retryButtonText: { color: colors.surface, ...textStyles.footnoteBold },
  ctaButton: { alignItems: 'center', backgroundColor: colors.accent, borderRadius: radius.md, marginTop: spacing.md, minWidth: 160, paddingHorizontal: spacing.lg, paddingVertical: spacing.md },
  ctaButtonText: { color: colors.surface, ...textStyles.footnoteBold },
});
