import * as DocumentPicker from 'expo-document-picker';
import { useState } from 'react';
import { Alert, StyleSheet, View } from 'react-native';
import { Button } from 'heroui-native/button';
import { Separator } from 'heroui-native/separator';
import { colors } from '../design/tokens';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';
import { AppIcon } from './AppIcon';
import { FloatingBottomSheet } from './FloatingBottomSheet';

type CaptureSheetProps = {
  isOpen: boolean;
  onClose: () => void;
};

export function CaptureSheet({ isOpen, onClose }: CaptureSheetProps) {
  const capture = useCaptureFlow();
  const [isBusy, setIsBusy] = useState(false);

  async function handleRecord() {
    if (isBusy) return;
    onClose();
    setIsBusy(true);
    try {
      await capture.openRecording();
    } catch {
      Alert.alert('録音を開始できません', 'ネイティブ録音ブリッジの状態を確認してください。');
    } finally {
      setIsBusy(false);
    }
  }

  async function handleImport() {
    if (isBusy) return;
    onClose();
    setIsBusy(true);
    try {
      const result = await DocumentPicker.getDocumentAsync({
        copyToCacheDirectory: true,
        multiple: false,
        type: ['audio/*', 'video/*'],
      });
      if (!result.canceled && result.assets[0]?.uri) {
        await capture.importAudio(result.assets[0].uri);
      }
    } catch {
      Alert.alert('取り込みに失敗しました', 'ファイル選択またはネイティブブリッジの状態を確認してください。');
    } finally {
      setIsBusy(false);
    }
  }

  function handleMeetingCapture() {
    if (isBusy) return;
    onClose();
    Alert.alert('準備中', '会議キャプチャーは次のネイティブ連携で追加します。');
  }

  return (
    <FloatingBottomSheet isOpen={isOpen} onClose={onClose}>
      <View style={styles.sheetSurface}>
        <Button
          accessibilityLabel={capture.isRecordingActive ? '録音に戻る' : '録音開始'}
          background={null}
          isDisabled={isBusy}
          onPress={() => void handleRecord()}
          style={styles.sheetAction}
          variant="ghost"
        >
          <AppIcon color={colors.text} name="mic-outline" size={18} />
          <Button.Label>{capture.isRecordingActive ? '録音に戻る' : '録音開始'}</Button.Label>
        </Button>
        <Separator orientation="horizontal" variant="thin" />
        <Button
          accessibilityLabel="インポート"
          background={null}
          isDisabled={isBusy}
          onPress={() => void handleImport()}
          style={styles.sheetAction}
          variant="ghost"
        >
          <AppIcon color={colors.text} name="attach-outline" size={18} />
          <Button.Label>インポート</Button.Label>
        </Button>
        <Separator orientation="horizontal" variant="thin" />
        <Button
          accessibilityLabel="会議キャプチャー"
          background={null}
          isDisabled={isBusy}
          onPress={handleMeetingCapture}
          style={styles.sheetAction}
          variant="ghost"
        >
          <AppIcon color={colors.text} name="chatbubble-outline" size={18} />
          <Button.Label>会議キャプチャー</Button.Label>
        </Button>
      </View>
    </FloatingBottomSheet>
  );
}

const styles = StyleSheet.create({
  sheetSurface: {
    backgroundColor: colors.surface,
    paddingBottom: 0,
    paddingHorizontal: 0,
    paddingTop: 0,
    width: '100%',
  },
  sheetAction: {
    justifyContent: 'flex-start',
    minHeight: 44,
    width: '100%' as const,
  },
});
