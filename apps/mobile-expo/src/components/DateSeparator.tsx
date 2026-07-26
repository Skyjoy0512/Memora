import { Separator, Surface, Text } from 'heroui-native';

type DateSeparatorProps = {
  date: string;
};

export function DateSeparator({ date }: DateSeparatorProps) {
  return (
    <Surface
      accessibilityRole="header"
      className="flex-row items-center gap-2 py-1"
      variant="transparent"
    >
      <Separator className="flex-1" />
      <Text color="muted" type="body-xs">{date}</Text>
      <Separator className="flex-1" />
    </Surface>
  );
}
