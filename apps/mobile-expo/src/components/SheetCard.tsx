import { Surface } from 'heroui-native';
import type { ComponentProps, ReactNode } from 'react';

type SheetCardProps = {
  children: ReactNode;
  style?: ComponentProps<typeof Surface>['style'];
};

export function SheetCard({ children, style }: SheetCardProps) {
  return (
    <Surface
      className="mx-3 mb-5 overflow-hidden rounded-2xl border border-border bg-surface"
      style={style}
      variant="default"
    >
      {children}
    </Surface>
  );
}
