import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, spacing } from '../design/tokens';

type TabBarProps<T extends string> = {
  tabs: Array<{ key: T; label: string }>;
  selected: T;
  onSelect: (key: T) => void;
};

export function TabBar<T extends string>({
  tabs,
  selected,
  onSelect,
}: TabBarProps<T>) {
  return (
    <View style={tabStyles.container} accessibilityRole="tablist">
      {tabs.map((tab) => {
        const isActive = tab.key === selected;
        return (
          <Pressable
            accessibilityLabel={tab.label}
            accessibilityRole="tab"
            accessibilityState={{ selected: isActive }}
            key={tab.key}
            onPress={() => onSelect(tab.key)}
            style={[tabStyles.tab, isActive && tabStyles.tabActive]}
          >
            <Text style={[tabStyles.label, isActive && tabStyles.labelActive]}>
              {tab.label}
            </Text>
            {isActive ? <View style={tabStyles.indicator} /> : null}
          </Pressable>
        );
      })}
    </View>
  );
}

const tabStyles = StyleSheet.create({
  container: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: spacing.lg,
  },
  tab: {
    alignItems: 'center',
    paddingBottom: spacing.sm,
    paddingTop: spacing.xs,
    position: 'relative',
  },
  tabActive: {},
  label: {
    color: colors.textTertiary,
    fontSize: 14,
    fontWeight: '600',
  },
  labelActive: {
    color: colors.accent,
  },
  indicator: {
    backgroundColor: colors.accent,
    borderRadius: 1,
    bottom: -1,
    height: 2,
    left: 0,
    position: 'absolute',
    right: 0,
  },
});
