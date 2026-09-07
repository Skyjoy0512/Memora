import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, spacing, textStyles } from '../design/tokens';
import { colors as themeColors } from '../theme/tokens';

type SegmentedControlProps<T extends string> = {
  segments: Array<{ key: T; label: string }>;
  selected: T;
  onSelect: (key: T) => void;
  /**
   * `tabs`  … Open Design v2 の `.detail-tabs`（下罫線・選択は面で示す）
   * `boxed` … 同 `.segment`（1px の枠で囲み、選択は黒地に白抜き）
   */
  variant?: 'tabs' | 'boxed';
  /** 暗転したヘッダー（`.file-header`）の中で使うとき。 */
  onDark?: boolean;
};

export function SegmentedControl<T extends string>({
  segments,
  selected,
  onSelect,
  variant = 'tabs',
  onDark = false,
}: SegmentedControlProps<T>) {
  const isBoxed = variant === 'boxed';

  return (
    <View
      accessibilityRole="tablist"
      style={[
        segStyles.container,
        isBoxed ? segStyles.boxedContainer : segStyles.tabsContainer,
        onDark && (isBoxed ? segStyles.boxedContainerOnDark : segStyles.tabsContainerOnDark),
      ]}
    >
      {segments.map((seg, index) => {
        const isActive = seg.key === selected;
        return (
          <Pressable
            accessibilityLabel={seg.label}
            accessibilityRole="tab"
            accessibilityState={{ selected: isActive }}
            hitSlop={isBoxed ? 5 : 0}
            key={seg.key}
            onPress={() => onSelect(seg.key)}
            style={({ pressed }) => [
              segStyles.segment,
              isBoxed ? segStyles.boxedSegment : segStyles.tabsSegment,
              isBoxed && index > 0 && segStyles.boxedDivider,
              onDark && segStyles.segmentOnDark,
              isActive && (isBoxed ? segStyles.boxedActive : segStyles.tabsActive),
              isActive && onDark && segStyles.activeOnDark,
              pressed && segStyles.segmentPressed,
            ]}
          >
            <Text
              style={[
                segStyles.label,
                onDark && segStyles.labelOnDark,
                isActive && (isBoxed ? segStyles.boxedLabelActive : segStyles.labelActive),
                isActive && onDark && segStyles.labelActiveOnDark,
              ]}
            >
              {seg.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const segStyles = StyleSheet.create({
  container: {
    borderRadius: 0,
    flexDirection: 'row',
  },
  tabsContainer: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
  },
  boxedContainer: {
    borderColor: colors.border,
    borderWidth: 1,
  },
  tabsContainerOnDark: {
    borderBottomColor: themeColors.dark.border,
  },
  boxedContainerOnDark: {
    borderColor: themeColors.dark.border,
  },
  segmentOnDark: {
    backgroundColor: 'transparent',
  },
  activeOnDark: {
    backgroundColor: themeColors.dark.surfaceAlt,
  },
  labelOnDark: {
    color: themeColors.dark.foregroundSecondary,
  },
  labelActiveOnDark: {
    color: themeColors.dark.foregroundPrimary,
  },
  segment: {
    alignItems: 'center',
    borderRadius: 0,
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: spacing.sm,
  },
  tabsSegment: {
    minHeight: 44,
  },
  boxedSegment: {
    backgroundColor: colors.surface,
    minHeight: 34,
  },
  boxedDivider: {
    borderLeftColor: colors.border,
    borderLeftWidth: 1,
  },
  tabsActive: {
    backgroundColor: colors.surfaceAlt,
  },
  boxedActive: {
    backgroundColor: colors.accent,
  },
  segmentPressed: {
    opacity: 0.72,
  },
  label: {
    color: colors.textSecondary,
    ...textStyles.footnote,
  },
  labelActive: {
    color: colors.text,
  },
  boxedLabelActive: {
    color: colors.textInverse,
  },
});
