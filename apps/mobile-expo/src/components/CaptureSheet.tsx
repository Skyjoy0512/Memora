import * as DocumentPicker from 'expo-document-picker';
import { useState } from 'react';
import { Alert, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';
import { AppIcon, type AppIconName } from './AppIcon';

type CaptureSheetProps = {
  isOpen: boolean;
  onClose: () => void;
};

/**
 * Open Design v2 の `.capture-menu`。
 * 小さなボトムシートではなく全画面。選択肢は親指の届く下端に寄せ、
 * ラベルは sheet-title と同じ大きさで「記録の入口」であることを明示する。
 */
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
    <Modal
      animationType="fade"
      onRequestClose={onClose}
      presentationStyle="overFullScreen"
      statusBarTranslucent
      transparent
      visible={isOpen}
    >
      <SafeAreaView edges={['top', 'bottom']} style={styles.menu}>
        <View style={styles.options}>
          <CaptureOption
            icon="mic-outline"
            label={capture.isRecordingActive ? '録音に戻る' : 'マイクで録音'}
            onPress={() => void handleRecord()}
          />
          <CaptureOption
            icon="document-outline"
            label="ファイルインポート"
            onPress={() => void handleImport()}
          />
          <CaptureOption
            icon="chatbubble-outline"
            label="オンライン会議キャプチャ"
            onPress={handleMeetingCapture}
          />
        </View>

        <Pressable
          accessibilityLabel="閉じる"
          accessibilityRole="button"
          onPress={onClose}
          style={({ pressed }) => [styles.close, pressed && styles.closePressed]}
        >
          <AppIcon color={colors.textInverse} name="close" size={24} />
        </Pressable>
      </SafeAreaView>
    </Modal>
  );
}

function CaptureOption({
  icon,
  label,
  onPress,
}: {
  icon: AppIconName;
  label: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.option, pressed && styles.optionPressed]}
    >
      <AppIcon color={colors.textSecondary} name={icon} size={24} />
      <Text style={styles.optionLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  menu: {
    backgroundColor: colors.canvas,
    flex: 1,
    justifyContent: 'flex-end',
    paddingBottom: spacing.xl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  options: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
  },
  option: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 64,
    paddingVertical: spacing.xs,
  },
  optionPressed: { backgroundColor: colors.surfaceAlt },
  optionLabel: { color: colors.text, flexShrink: 1, ...textStyles.title2 },
  close: {
    alignItems: 'center',
    alignSelf: 'center',
    backgroundColor: colors.accent,
    borderColor: colors.accent,
    borderRadius: radius.circle,
    borderWidth: 1,
    height: 52,
    justifyContent: 'center',
    marginTop: spacing.xxl,
    width: 52,
  },
  closePressed: { opacity: 0.72 },
});
