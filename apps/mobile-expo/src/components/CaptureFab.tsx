import { LiquidGlassView, isLiquidGlassSupported } from '@callstack/liquid-glass';
import { Menu } from 'heroui-native/menu';
import * as DocumentPicker from 'expo-document-picker';
import { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';
import { colors as themeColors, shadow as themeShadow, touchTarget } from '../theme/tokens';
import { colors, textStyles } from '../design/tokens';
import { AppIcon } from './AppIcon';

export function CaptureFab() {
  const insets = useSafeAreaInsets();
  const capture = useCaptureFlow();
  const [isBusy, setIsBusy] = useState(false);
  const [isMenuOpen, setMenuOpen] = useState(false);

  async function handleRecord() {
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

  const fabBottom = insets.bottom + 57;

  return (
    <View
      style={[styles.container, { bottom: fabBottom }]}
      pointerEvents="box-none"
    >
      <Menu isOpen={isMenuOpen} onOpenChange={setMenuOpen} isDisabled={isBusy}>
        <Menu.Trigger asChild>
          <Pressable
            accessibilityLabel={isMenuOpen ? '追加メニューを閉じる' : '追加メニューを開く'}
            accessibilityRole="button"
            accessibilityState={{ busy: isBusy, expanded: isMenuOpen }}
            disabled={isBusy}
          >
            <LiquidGlassView
              colorScheme="light"
              effect="clear"
              interactive
              pointerEvents="none"
              style={[
                styles.fab,
                styles.fabShadow,
                !isLiquidGlassSupported && styles.fabFallback,
              ]}
            >
              <View style={styles.fabInner}>
                {isBusy ? (
                  <ActivityIndicator color={colors.text} size="small" />
                ) : (
                  <AppIcon color={colors.text} name="add" size={20} />
                )}
              </View>
            </LiquidGlassView>
          </Pressable>
        </Menu.Trigger>
        <Menu.Portal>
          <Menu.Overlay />
          <Menu.Content align="center" placement="top" presentation="popover">
            <Menu.Item
              isDisabled={isBusy}
              onPress={() => void handleRecord()}
            >
              <Menu.ItemTitle style={styles.menuItemTitle}>
                {capture.isRecordingActive ? '録音に戻る' : '録音開始'}
              </Menu.ItemTitle>
            </Menu.Item>
            <Menu.Item
              isDisabled={isBusy}
              onPress={() => void handleImport()}
            >
              <Menu.ItemTitle style={styles.menuItemTitle}>インポート</Menu.ItemTitle>
            </Menu.Item>
            <Menu.Item
              isDisabled={isBusy}
              onPress={() => {
                Alert.alert('準備中', '会議キャプチャーは次のネイティブ連携で追加します。');
              }}
            >
              <Menu.ItemTitle style={styles.menuItemTitle}>会議キャプチャー</Menu.ItemTitle>
            </Menu.Item>
          </Menu.Content>
        </Menu.Portal>
      </Menu>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    left: 0,
    pointerEvents: 'box-none',
    position: 'absolute',
    right: 0,
    zIndex: 100,
  },
  fab: {
    alignItems: 'center',
    borderRadius: touchTarget.fab / 2,
    height: touchTarget.fab,
    justifyContent: 'center',
    overflow: 'hidden',
    width: touchTarget.fab,
  },
  fabFallback: {
    backgroundColor: themeColors.light.glassFallback,
    borderColor: themeColors.light.glassBorderFallback,
    borderWidth: 1,
  },
  fabInner: {
    alignItems: 'center',
    height: '100%',
    justifyContent: 'center',
    width: '100%',
  },
  fabShadow: themeShadow.recordingFab,
  menuItemTitle: {
    color: colors.text,
    ...textStyles.body,
  },
});
