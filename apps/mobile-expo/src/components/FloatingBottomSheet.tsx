import { StyleSheet, useColorScheme } from 'react-native';
import { BottomSheet } from 'heroui-native/bottom-sheet';
import type { ReactNode } from 'react';
import { colors, darkColors, radius, spacing } from '../design/tokens';

type FloatingBottomSheetProps = {
  children: ReactNode;
  isOpen: boolean;
  onClose: () => void;
};

export function FloatingBottomSheet({ children, isOpen, onClose }: FloatingBottomSheetProps) {
  const palette = useColorScheme() === 'dark' ? darkColors : colors;

  return (
    <BottomSheet isOpen={isOpen} onOpenChange={(nextIsOpen) => !nextIsOpen && onClose()}>
      <BottomSheet.Portal>
        <BottomSheet.Overlay isCloseOnPress />
        <BottomSheet.Content
        backgroundStyle={styles.transparent}
        contentContainerProps={{ accessible: false, style: styles.content }}
        enableDynamicSizing
        enablePanDownToClose
        handleIndicatorStyle={[styles.handleIndicator, { backgroundColor: palette.border }]}
        handleStyle={styles.handle}
        index={0}
        >
          {children}
        </BottomSheet.Content>
      </BottomSheet.Portal>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({
  content: { backgroundColor: 'transparent' },
  handle: { paddingBottom: spacing.sm, paddingTop: spacing.md },
  handleIndicator: { borderRadius: radius.pill, height: radius.xs, width: spacing.xl },
  transparent: { backgroundColor: 'transparent' },
});
