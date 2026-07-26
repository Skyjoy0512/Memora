import type { ReactNode } from 'react';
import { Surface, Text } from 'heroui-native';

type Props = {
  title: string;
  children: ReactNode;
  action?: ReactNode;
};

export function Section({ title, children, action }: Props) {
  return (
    <Surface className="gap-3" variant="transparent">
      <Surface className="flex-row items-center justify-between" variant="transparent">
        <Text color="muted" type="body-xs" weight="medium">{title}</Text>
        {action}
      </Surface>
      {children}
    </Surface>
  );
}
