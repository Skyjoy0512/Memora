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
      className="min-h-11"
      onValueChange={(value) => onSelect(value as T)}
      value={selected}
      variant="secondary"
    >
      <Tabs.List className="min-h-11">
        {segments.map((seg) => (
          <Tabs.Trigger
            accessibilityLabel={seg.label}
            className="min-h-11"
            key={seg.key}
            value={seg.key}
          >
            <Tabs.Label>{seg.label}</Tabs.Label>
          </Tabs.Trigger>
        ))}
        <Tabs.Indicator />
      </Tabs.List>
    </Tabs>
  );
}
