import { StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing } from '../design/tokens';
import type { AudioStatus } from '../types/memora';

const statusCopy: Record<AudioStatus, string> = {
  ready: 'Ready',
  summarized: '要約済み',
  transcribing: '文字起こし中',
  failed: '確認が必要',
};

const statusColors: Record<AudioStatus, { backgroundColor: string; color: string }> = {
  ready: { backgroundColor: colors.surfaceAlt, color: colors.textSecondary },
  summarized: { backgroundColor: colors.successSoft, color: colors.success },
  transcribing: { backgroundColor: colors.warningSoft, color: colors.warning },
  failed: { backgroundColor: colors.dangerSoft, color: colors.danger },
};

export function StatusPill({ status }: { status: AudioStatus }) {
  const tone = statusColors[status];
  return (
    <View style={[styles.pill, { backgroundColor: tone.backgroundColor }]}>
      <Text style={[styles.label, { color: tone.color }]}>{statusCopy[status]}</Text>
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
