import { Chip, type ChipColor } from 'heroui-native/chip';
import { StyleSheet } from 'react-native';
import { radius, spacing, textStyles } from '../design/tokens';
import type { AudioStatus } from '../types/memora';

const statusCopy: Record<AudioStatus, string> = {
  queued: '文字起こし待ち',
  ready: '文字起こし済み',
  summarized: '要約済み',
  transcribing: '文字起こし中',
  failed: '確認が必要',
};

const statusColors: Record<AudioStatus, ChipColor> = {
  queued: 'default',
  ready: 'default',
  summarized: 'success',
  transcribing: 'warning',
  failed: 'danger',
};

const fallbackCopy = '処理待ち';
const fallbackColor: ChipColor = 'default';

export function StatusPill({ status }: { status: AudioStatus | string }) {
  const color = statusColors[status as AudioStatus] ?? fallbackColor;
  const copy = statusCopy[status as AudioStatus] ?? fallbackCopy;

  return (
    <Chip
      accessibilityRole="text"
      animation="disable-all"
      background={null}
      color={color}
      size="sm"
      style={styles.pill}
      variant="soft"
    >
      <Chip.Label style={styles.label}>{copy}</Chip.Label>
    </Chip>
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
    ...textStyles.captionBold,
  },
});
