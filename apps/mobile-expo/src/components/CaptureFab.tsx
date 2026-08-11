import { LiquidGlassView, isLiquidGlassSupported } from '@callstack/liquid-glass';
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
import { usePathname } from 'expo-router';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';
import { colors as themeColors, shadow as themeShadow, touchTarget } from '../theme/tokens';
import { colors } from '../design/tokens';
import { AppIcon } from './AppIcon';
import { FloatingBottomSheet } from './FloatingBottomSheet';
import { Button } from 'heroui-native/button';
import { Separator } from 'heroui-native/separator';
import {
  HOME_COMPOSER_GAP,
  HOME_COMPOSER_HEIGHT,
  HOME_PROJECT_SELECTOR_HEIGHT,
  useHomeComposer,
} from './HomeComposer';

export function CaptureFab() {
  const insets = useSafeAreaInsets();
  const isHome = usePathname() === '/';
  const capture = useCaptureFlow();
  const { viewMode } = useHomeComposer();
  const [isBusy, setIsBusy] = useState(false);
  const [isSheetOpen, setSheetOpen] = useState(false);

  async function handleRecord() {
    setSheetOpen(false);
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
    setSheetOpen(false);
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
    setSheetOpen(false);
    Alert.alert('準備中', '会議キャプチャーは次のネイティブ連携で追加します。');
  }

  // Home タブでは composer がタブバー直上に常時表示されるため、FAB をその分持ち上げる。
  const homeAccessoryHeight =
    HOME_COMPOSER_HEIGHT +
    HOME_COMPOSER_GAP +
    (viewMode === 'projects' ? HOME_PROJECT_SELECTOR_HEIGHT : 0);
  const fabBottom = insets.bottom + 57 + (isHome ? homeAccessoryHeight : 0);

  return (
    <>
      <View
        style={[styles.container, { bottom: fabBottom }]}
        pointerEvents="box-none"
      >
        <Pressable
          accessibilityLabel={isSheetOpen ? '追加メニューを閉じる' : '追加メニューを開く'}
          accessibilityRole="button"
          accessibilityState={{ busy: isBusy, expanded: isSheetOpen }}
          disabled={isBusy}
          onPress={() => setSheetOpen(true)}
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
      </View>
      <FloatingBottomSheet isOpen={isSheetOpen} onClose={() => setSheetOpen(false)}>
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
    </>
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
