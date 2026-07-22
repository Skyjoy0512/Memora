import { LayoutAnimation, Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, shadow, textStyles } from '../design/tokens';

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
            onPress={() => {
              LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
              onSelect(seg.key);
            }}
            style={[segStyles.segment, isActive && segStyles.segmentActive]}
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
    borderRadius: radius.sm,
    flexDirection: 'row',
    padding: 3,
  },
  segment: {
    alignItems: 'center',
    borderRadius: 6,
    flex: 1,
    justifyContent: 'center',
    minHeight: 32,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
  },
  segmentActive: {
    backgroundColor: colors.surface,
    ...shadow.card,
  },
  label: {
    color: colors.textSecondary,
    ...textStyles.footnoteBold,
  },
  labelActive: {
    color: colors.text,
  },
});
