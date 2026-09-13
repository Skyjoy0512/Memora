import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { AppIcon } from './AppIcon';
import { SecondaryAction } from './Buttons';
import { colors, spacing, textStyles } from '../design/tokens';

export function LoadingState({ label = '読み込み中' }: { label?: string }) {
  return (
    <View style={styles.block}>
      <View style={styles.inner}>
        <ActivityIndicator color={colors.textSecondary} size="small" />
        <Text style={styles.title}>{label}</Text>
      </View>
    </View>
  );
}

/**
 * Open Design v2 の `.empty-state`。
 * 破線の枠に中央寄せで「何が無いか」と「次に何をするか」だけを置く。
 * アイコンや塗りは足さない（空であること自体は失敗ではない）。
 */
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
    <View style={styles.block}>
      <View style={styles.inner}>
        <Text style={styles.title}>{title}</Text>
        {body ? <Text style={styles.body}>{body}</Text> : null}
        {actionLabel && onAction ? (
          <SecondaryAction
            accessibilityLabel={actionLabel}
            label={actionLabel}
            onPress={onAction}
            style={styles.action}
          />
        ) : null}
      </View>
    </View>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <View style={styles.block}>
      <View style={styles.inner}>
        <View style={styles.errorTitleRow}>
          <AppIcon color={colors.danger} name="warning-outline" size={16} />
          <Text style={styles.title}>読み込みに失敗しました</Text>
        </View>
        <Text style={styles.body}>{message}</Text>
        {onRetry ? (
          <SecondaryAction
            accessibilityLabel="ファイルを再読み込み"
            label="再試行"
            onPress={onRetry}
            style={styles.action}
          />
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  block: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: 0,
    borderStyle: 'dashed',
    borderWidth: 1,
    justifyContent: 'center',
    marginTop: spacing.xl,
    minHeight: 224,
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.xxl,
  },
  inner: {
    alignItems: 'center',
    gap: spacing.xs,
    maxWidth: 280,
  },
  errorTitleRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  title: {
    color: colors.text,
    textAlign: 'center',
    ...textStyles.sectionTitle,
  },
  body: {
    color: colors.textSecondary,
    textAlign: 'center',
    ...textStyles.footnote,
  },
  action: { marginTop: spacing.md },
});
