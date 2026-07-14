import { useEffect, useRef, type ReactNode } from 'react';
import { StyleSheet } from 'react-native';
import { BottomSheetBackdrop, BottomSheetModal, BottomSheetView } from '@gorhom/bottom-sheet';

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
      backgroundStyle={styles.transparent}
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
  content: { backgroundColor: 'transparent' },
  handle: { paddingBottom: 8, paddingTop: 12 },
  handleIndicator: { backgroundColor: '#D1D1D6', height: 4, width: 36 },
  transparent: { backgroundColor: 'transparent' },
});
