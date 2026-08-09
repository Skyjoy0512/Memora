import { Button } from 'heroui-native/button';
import { Separator } from 'heroui-native/separator';
import { Spinner } from 'heroui-native/spinner';
import { AppIcon } from './AppIcon';
import { StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, textStyles } from '../design/tokens';

export function LoadingState({ label = '読み込み中' }: { label?: string }) {
  return (
    <View style={styles.container}>
      <Separator />
      <View style={styles.headerRow}>
        <Spinner size="sm" />
        <Text style={styles.title}>{label}</Text>
      </View>
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
    <View style={styles.container}>
      <Separator />
      <View style={styles.headerRow}>
        <AppIcon color={colors.textSecondary} name="file-tray-outline" size={16} />
        <Text style={styles.title}>{title}</Text>
      </View>
      {body ? <Text style={styles.body}>{body}</Text> : null}
      {actionLabel && onAction ? (
        <Button
          accessibilityLabel={actionLabel}
          onPress={onAction}
          variant="primary"
          style={{ borderRadius: radius.sm }}
        >
          {actionLabel}
        </Button>
      ) : null}
    </View>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <View style={styles.container}>
      <Separator />
      <View style={styles.headerRow}>
        <AppIcon color={colors.danger} name="warning-outline" size={16} />
        <Text style={styles.title}>読み込みに失敗しました</Text>
      </View>
      <Text style={styles.body}>{message}</Text>
      {onRetry ? (
        <Button
          accessibilityLabel="ファイルを再読み込み"
          onPress={onRetry}
          variant="primary"
          style={{ borderRadius: radius.sm }}
        >
          再試行
        </Button>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: spacing.xs,
    paddingTop: spacing.xs,
  },
  headerRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    minHeight: 44,
  },
  title: {
    color: colors.text,
    ...textStyles.callout,
  },
  body: {
    color: colors.textSecondary,
    ...textStyles.footnote,
  },
});
