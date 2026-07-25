import { StyleSheet } from 'react-native';
import { Tabs } from 'heroui-native';

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
    <Tabs
      onValueChange={(value) => onSelect(value as T)}
      style={segStyles.container}
      value={selected}
      variant="secondary"
    >
      <Tabs.List>
        {segments.map((seg) => (
          <Tabs.Trigger accessibilityLabel={seg.label} key={seg.key} value={seg.key}>
            <Tabs.Label>{seg.label}</Tabs.Label>
          </Tabs.Trigger>
        ))}
        <Tabs.Indicator />
      </Tabs.List>
    </Tabs>
  );
}

const segStyles = StyleSheet.create({
  container: {
    minHeight: 44,
  },
});
