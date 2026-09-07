import { StyleSheet, Text, View } from 'react-native';
import { colors, spacing, textStyles } from '../design/tokens';
import type { AudioStatus } from '../types/memora';
import { formatStatus } from '../utils/formatStatus';

/**
 * Open Design v2 の `.status-badge`。
 * 状態を色で符号化しない（成功=緑を廃止）。完了系は黒塗り、
 * それ以外は同じ字形の枠線のみで表す。文言が正本。
 */
type Variant = 'solid' | 'outline';

const solidStatuses = new Set(['completed', 'summarized']);

export function StatusPill({
  status,
  variant,
  onDark = false,
}: {
  status: AudioStatus | string;
  variant?: Variant;
  onDark?: boolean;
}) {
  const resolved: Variant = variant ?? (solidStatuses.has(status.toLowerCase()) ? 'solid' : 'outline');
  const ink = onDark ? colors.surface : colors.text;
  const paper = onDark ? colors.text : colors.surface;

  return (
    <View
      accessibilityRole="text"
      style={[
        styles.badge,
        { borderColor: ink },
        resolved === 'solid' && { backgroundColor: ink },
      ]}
    >
      <Text style={[styles.label, { color: resolved === 'solid' ? paper : ink }]}>
        {formatStatus(status)}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignSelf: 'flex-start',
    borderRadius: 0,
    borderWidth: 1,
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xxs,
  },
  label: {
    ...textStyles.label,
  },
});
