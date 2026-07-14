import { AppIcon, type AppIconName } from './AppIcon';
import { LiquidGlassContainerView, LiquidGlassView, isLiquidGlassSupported } from '@callstack/liquid-glass';
import * as DocumentPicker from 'expo-document-picker';
import { useState } from 'react';
import {
  Alert,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';

const items = [
  { icon: 'home' as AppIconName, label: 'ホーム', routeName: 'index' },
  { icon: 'checkmark-circle' as AppIconName, label: 'タスク', routeName: 'tasks' },
  { icon: 'sparkles' as AppIconName, label: 'Ask', routeName: 'ask-ai' },
  { icon: 'settings' as AppIconName, label: '設定', routeName: 'settings' },
];

type FloatingTabBarProps = {
  navigation: {
    emit: (event: { canPreventDefault: true; target: string; type: 'tabPress' }) => { defaultPrevented: boolean };
    navigate: (routeName: string) => void;
  };
  state: {
    index: number;
    routes: Array<{ key: string; name: string }>;
  };
};

export function V6FloatingTabBar({ navigation, state }: FloatingTabBarProps) {
  const insets = useSafeAreaInsets();
  const capture = useCaptureFlow();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isBusy, setIsBusy] = useState(false);

  const selectedRoute = state.routes[state.index]?.name;

  function navigate(routeName: string) {
    const route = state.routes.find((candidate) => candidate.name === routeName);
    if (!route) return;

    const event = navigation.emit({
      canPreventDefault: true,
      target: route.key,
      type: 'tabPress',
    });

    if (!event.defaultPrevented) {
      navigation.navigate(routeName);
    }
    setIsMenuOpen(false);
  }

  async function handleRecord() {
    setIsBusy(true);
    try {
      await capture.openRecording();
      setIsMenuOpen(false);
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
      setIsMenuOpen(false);
    } catch {
      Alert.alert('取り込みに失敗しました', 'ファイル選択またはネイティブブリッジの状態を確認してください。');
    } finally {
      setIsBusy(false);
    }
  }

  return (
    <>
      <Modal animationType="fade" onRequestClose={() => setIsMenuOpen(false)} transparent visible={isMenuOpen}>
        <View style={styles.modalRoot}>
          <Pressable
            accessibilityLabel="追加メニューを閉じる"
            onPress={() => setIsMenuOpen(false)}
            style={styles.scrim}
          />
          <View style={[styles.menu, { bottom: insets.bottom + 72 }]}>
            <MenuItem
              disabled={isBusy}
              label={capture.isRecordingActive ? '録音に戻る' : '録音開始'}
              onPress={() => void handleRecord()}
              recording
            />
            <MenuItem disabled={isBusy} label="インポート" onPress={() => void handleImport()} />
            <MenuItem
              disabled={isBusy}
              label="会議キャプチャー"
              onPress={() => {
                setIsMenuOpen(false);
                Alert.alert('準備中', '会議キャプチャーは次のネイティブ連携で追加します。');
              }}
            />
          </View>
        </View>
      </Modal>

      <View style={[styles.container, { height: insets.bottom + 60, paddingBottom: insets.bottom }]}>
        <LiquidGlassContainerView spacing={10} style={styles.dock}>
          <LiquidGlassView
            colorScheme="light"
            effect="clear"
            style={[styles.glassPill, !isLiquidGlassSupported && styles.glassFallback]}
            tintColor="rgba(255,255,255,0.04)"
          >
            {items.map((item) => {
              const focused = selectedRoute === item.routeName;
              const badgeCount = item.routeName === 'tasks' ? 1 : 0;

              return (
                <Pressable
                  accessibilityLabel={item.label}
                  accessibilityRole="tab"
                  accessibilityState={{ selected: focused }}
                  key={item.routeName}
                  onPress={() => navigate(item.routeName)}
                  style={({ pressed }) => [styles.tabButton, pressed && styles.pressed]}
                >
                  <View style={[styles.tabIcon, focused && styles.tabIconFocused]}>
                    <AppIcon color={focused ? '#0D0D0D' : 'rgba(13,13,13,0.55)'} name={item.icon} size={21} weight={focused ? 'Filled' : 'Outline'} />
                  </View>
                  {badgeCount > 0 ? <View accessibilityLabel={`未完了タスク ${badgeCount} 件`} style={styles.badge}><Text style={styles.badgeText}>{badgeCount}</Text></View> : null}
                </Pressable>
              );
            })}
          </LiquidGlassView>

          <LiquidGlassView
            colorScheme="light"
            effect="clear"
            interactive
            style={[styles.fab, !isLiquidGlassSupported && styles.glassFallback]}
            tintColor="rgba(255,255,255,0.04)"
          >
            <Pressable
              accessibilityLabel={isMenuOpen ? '追加メニューを閉じる' : '追加メニューを開く'}
              accessibilityRole="button"
              onPress={() => setIsMenuOpen((open) => !open)}
              style={({ pressed }) => [styles.fabPress, pressed && styles.pressed]}
            >
              <AppIcon color="#0D0D0D" name={isMenuOpen ? 'close' : 'add'} size={isMenuOpen ? 18 : 20} />
            </Pressable>
          </LiquidGlassView>
        </LiquidGlassContainerView>
      </View>
    </>
  );
}

function MenuItem({ disabled, label, onPress, recording = false }: { disabled: boolean; label: string; onPress: () => void; recording?: boolean }) {
  return (
    <Pressable disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.menuItem, (pressed || disabled) && styles.menuItemPressed]}>
      <Text style={styles.menuText}>{label}</Text>
      {recording ? <View style={styles.recordingDot} /> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignItems: 'center',
    backgroundColor: '#0D0D0D',
    borderColor: 'rgba(255,255,255,0.9)',
    borderRadius: 9,
    borderWidth: 1.5,
    color: '#FFFFFF',
    height: 18,
    justifyContent: 'center',
    minWidth: 18,
    overflow: 'hidden',
    position: 'absolute',
    right: 1,
    top: 0,
  },
  badgeText: { color: '#FFFFFF', fontSize: 10, fontVariant: ['tabular-nums'], fontWeight: '800', lineHeight: 12, textAlign: 'center' },
  container: { backgroundColor: 'transparent', paddingHorizontal: 16 },
  dock: { flexDirection: 'row', gap: 10, height: 60 },
  fab: {
    alignItems: 'center',
    borderColor: 'rgba(255,255,255,0.22)',
    borderRadius: 30,
    borderWidth: 1,
    height: 60,
    justifyContent: 'center',
    overflow: 'hidden',
    shadowColor: '#000000',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: 0.18,
    shadowRadius: 16,
    width: 60,
  },
  fabPress: { alignItems: 'center', height: '100%', justifyContent: 'center', width: '100%' },
  glassFallback: { backgroundColor: 'rgba(255,255,255,0.7)' },
  glassPill: {
    borderColor: 'rgba(255,255,255,0.22)',
    borderRadius: 30,
    borderWidth: 1,
    flex: 1,
    flexDirection: 'row',
    height: 60,
    overflow: 'hidden',
    padding: 8,
    shadowColor: '#000000',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: 0.18,
    shadowRadius: 16,
  },
  menu: { alignItems: 'flex-end', gap: 12, position: 'absolute', right: 16 },
  menuItem: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 24,
    flexDirection: 'row',
    gap: 10,
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  menuItemPressed: { opacity: 0.7, transform: [{ scale: 0.93 }] },
  menuText: { color: '#0D0D0D', fontSize: 14.5, fontWeight: '600' },
  modalRoot: { flex: 1 },
  pressed: { opacity: 0.9, transform: [{ scale: 0.93 }] },
  recordingDot: { backgroundColor: '#FF3030', borderRadius: 5, height: 10, width: 10 },
  scrim: { backgroundColor: 'rgba(0,0,0,0.28)', ...StyleSheet.absoluteFill },
  tabButton: { alignItems: 'center', flex: 1, height: 44, justifyContent: 'center' },
  tabIcon: { alignItems: 'center', borderRadius: 22, height: 44, justifyContent: 'center', width: '100%' },
  tabIconFocused: { backgroundColor: 'rgba(13,13,13,0.08)' },
});
