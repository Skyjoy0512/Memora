import { Chip, type ChipColor } from 'heroui-native/chip';
import { StyleSheet } from 'react-native';
import { radius, spacing, textStyles } from '../design/tokens';
import type { AudioStatus } from '../types/memora';
import { formatStatus } from '../utils/formatStatus';

const statusColors: Record<string, ChipColor> = {
  queued: 'default',
  ready: 'default',
  summarized: 'success',
  transcribing: 'warning',
  processing: 'warning',
  completed: 'success',
  failed: 'danger',
};

const fallbackColor: ChipColor = 'default';

export function StatusPill({ status }: { status: AudioStatus | string }) {
  const color = statusColors[status.toLowerCase()] ?? fallbackColor;
  const copy = formatStatus(status);

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
