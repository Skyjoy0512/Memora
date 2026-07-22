import { AppIcon } from './AppIcon';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import type {
  TranscriptionEventDTO,
  TranscriptionTaskDTO,
} from '../native/MemoraNative.types';

type Props = {
  error: string | null;
  event: TranscriptionEventDTO | null;
  isRunning: boolean;
  onCancel: () => void;
  onStart: () => void;
  task: TranscriptionTaskDTO | null;
};

export function TranscriptionProgressCard({
  error,
  event,
  isRunning,
  onCancel,
  onStart,
  task,
}: Props) {
  const progress = Math.round((event?.progress ?? task?.progress ?? 0) * 100);
  const isCompleted = task?.status === 'completed';

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <View style={styles.iconWrap}>
          <AppIcon color={colors.accent} name="pulse-outline" size={20} />
        </View>
        <View style={styles.titleBlock}>
          <Text style={styles.title}>Native bridge event preview</Text>
          <Text style={styles.subtitle}>
            {event?.message ?? 'Swift STT event stream に差し替える前の mock 進捗です。'}
          </Text>
        </View>
      </View>

      <View style={styles.progressTrack}>
        <View style={[styles.progressFill, { width: `${progress}%` }]} />
      </View>
      <Text style={styles.progressText}>{progress}%</Text>

      {error ? <Text style={styles.errorText}>{error}</Text> : null}

      <View style={styles.actions}>
        <Pressable
          disabled={isRunning}
          onPress={onStart}
          style={[styles.primaryButton, isRunning && styles.disabledButton]}
        >
          <Text style={styles.primaryText}>{isCompleted ? '再実行' : '開始'}</Text>
        </Pressable>
        <Pressable disabled={!isRunning} onPress={onCancel} style={styles.secondaryButton}>
          <Text style={[styles.secondaryText, !isRunning && styles.disabledText]}>
            キャンセル
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.lg,
    borderWidth: 1,
    gap: spacing.md,
    padding: spacing.lg,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  iconWrap: {
    alignItems: 'center',
    backgroundColor: colors.accentSoft,
    borderRadius: radius.pill,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  titleBlock: {
    flex: 1,
    gap: 4,
  },
  title: {
    color: colors.text,
    ...textStyles.callout,
  },
  subtitle: {
    color: colors.textSecondary,
    ...textStyles.footnote,
  },
  progressTrack: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.pill,
    height: 10,
    overflow: 'hidden',
  },
  progressFill: {
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    height: '100%',
  },
  progressText: {
    color: colors.textSecondary,
    textAlign: 'right',
    ...textStyles.captionBold,
  },
  errorText: {
    color: colors.danger,
    ...textStyles.footnoteBold,
  },
  actions: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    flex: 1,
    paddingVertical: spacing.md,
  },
  disabledButton: {
    opacity: 0.45,
  },
  primaryText: {
    color: colors.surface,
    ...textStyles.bodyBold,
  },
  secondaryButton: {
    alignItems: 'center',
    backgroundColor: colors.accentSoft,
    borderRadius: radius.pill,
    flex: 1,
    paddingVertical: spacing.md,
  },
  secondaryText: {
    color: colors.accent,
    ...textStyles.bodyBold,
  },
  disabledText: {
    color: colors.textTertiary,
  },
});
