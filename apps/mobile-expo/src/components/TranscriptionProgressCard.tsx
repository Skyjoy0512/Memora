import { AppIcon } from './AppIcon';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import type {
  TranscriptionEventDTO,
  TranscriptionTaskDTO,
} from '../native/MemoraNative.types';

type Props = {
  event: TranscriptionEventDTO | null;
  onCancel: () => void;
  task: TranscriptionTaskDTO | null;
};

export function TranscriptionProgressCard({
  event,
  onCancel,
  task,
}: Props) {
  const progress = Math.round((event?.progress ?? task?.progress ?? 0) * 100);

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <View style={styles.iconWrap}>
          <AppIcon color={colors.accent} name="pulse-outline" size={20} />
        </View>
        <View style={styles.titleBlock}>
          <Text style={styles.title}>文字起こし</Text>
          <Text style={styles.subtitle}>
            {event?.message ?? '音声を解析しています'}
          </Text>
        </View>
      </View>

      <View style={styles.progressTrack}>
        <View style={[styles.progressFill, { width: `${progress}%` }]} />
      </View>
      <Text style={styles.progressText}>{progress}%</Text>

      <View style={styles.actions}>
        <Pressable onPress={onCancel} style={styles.secondaryButton}>
          <Text style={styles.secondaryText}>キャンセル</Text>
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
  actions: {
    flexDirection: 'row',
    gap: spacing.md,
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
});
