import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, textStyles } from '../design/tokens';

type SegmentedControlProps<T extends string> = {
  segments: Array<{ key: T; label: string }>;
  selected: T;
  onSelect: (key: T) => void;
};

export function SegmentedControl<T extends string>({
  segments,
  selected,
  onSelect,
}: SegmentedControlProps<T>) {
  return (
    <View style={segStyles.container} accessibilityRole="tablist">
      {segments.map((seg) => {
        const isActive = seg.key === selected;
        return (
          <Pressable
            accessibilityLabel={seg.label}
            accessibilityRole="tab"
            accessibilityState={{ selected: isActive }}
            key={seg.key}
            onPress={() => onSelect(seg.key)}
            style={({ pressed }) => [
              segStyles.segment,
              isActive && segStyles.segmentActive,
              pressed && segStyles.segmentPressed,
            ]}
          >
            <Text style={[segStyles.label, isActive && segStyles.labelActive]}>
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
    backgroundColor: colors.surfaceAlt,
    borderColor: colors.border,
    borderRadius: radius.sm,
    borderWidth: 1,
    flexDirection: 'row',
    padding: spacing.xxs,
  },
  segment: {
    alignItems: 'center',
    borderRadius: radius.xs,
    flex: 1,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  segmentActive: {
    backgroundColor: colors.accentSoft,
  },
  segmentPressed: {
    opacity: 0.72,
  },
  label: {
    color: colors.textSecondary,
    ...textStyles.footnoteBold,
  },
  labelActive: {
    color: colors.text,
  },
});
