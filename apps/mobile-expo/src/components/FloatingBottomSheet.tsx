import { useEffect, useRef, type ReactNode } from 'react';
import { StyleSheet } from 'react-native';
import { BottomSheetBackdrop, BottomSheetModal, BottomSheetView } from '@gorhom/bottom-sheet';
import { colors, radius } from '../design/tokens';

type FloatingBottomSheetProps = {
  children: ReactNode;
  isOpen: boolean;
  onClose: () => void;
};

export function FloatingBottomSheet({ children, isOpen, onClose }: FloatingBottomSheetProps) {
  const sheetRef = useRef<BottomSheetModal>(null);
  const isPresentedRef = useRef(false);

  useEffect(() => {
    const sheet = sheetRef.current;

    if (isOpen) {
      if (!sheet || isPresentedRef.current) return;
      isPresentedRef.current = true;
      sheet.present();
      return;
    }

    if (isPresentedRef.current) sheet?.dismiss();
  }, [isOpen]);

  function handleDismiss() {
    isPresentedRef.current = false;
    onClose();
  }

  return (
    <BottomSheetModal
      accessible={false}
      ref={sheetRef}
      backdropComponent={(props) => <BottomSheetBackdrop {...props} appearsOnIndex={0} disappearsOnIndex={-1} pressBehavior="close" />}
      backgroundStyle={styles.base}
      enableDynamicSizing
      enablePanDownToClose
      handleIndicatorStyle={styles.handleIndicator}
      handleStyle={styles.handle}
      index={0}
      onDismiss={handleDismiss}
    >
      <BottomSheetView accessible={false} style={styles.content}>{children}</BottomSheetView>
    </BottomSheetModal>
  );
}

const styles = StyleSheet.create({
  base: { backgroundColor: colors.surface, borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg },
  content: { backgroundColor: colors.surface },
  handle: { paddingBottom: 8, paddingTop: 12 },
  handleIndicator: { backgroundColor: colors.textTertiary, height: 4, width: 36 },
});
