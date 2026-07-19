import { StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing } from '../design/tokens';
import type { AudioStatus } from '../types/memora';

const statusCopy: Record<AudioStatus, string> = {
  queued: '文字起こし待ち',
  ready: '文字起こし済み',
  summarized: '要約済み',
  transcribing: '文字起こし中',
  failed: '確認が必要',
};

const statusColors: Record<AudioStatus, { backgroundColor: string; color: string }> = {
  queued: { backgroundColor: colors.surfaceAlt, color: colors.textSecondary },
  ready: { backgroundColor: colors.surfaceAlt, color: colors.textSecondary },
  summarized: { backgroundColor: colors.successSoft, color: colors.success },
  transcribing: { backgroundColor: colors.warningSoft, color: colors.warning },
  failed: { backgroundColor: colors.dangerSoft, color: colors.danger },
};

const fallbackCopy = '処理待ち';
const fallbackTone = { backgroundColor: colors.surfaceAlt, color: colors.textSecondary };

export function StatusPill({ status }: { status: AudioStatus | string }) {
  const tone = statusColors[status as AudioStatus] ?? fallbackTone;
  const copy = statusCopy[status as AudioStatus] ?? fallbackCopy;
  return (
    <View style={[styles.pill, { backgroundColor: tone.backgroundColor }]}>
      <Text style={[styles.label, { color: tone.color }]}>{copy}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    alignSelf: 'flex-start',
    borderRadius: radius.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
  },
});
