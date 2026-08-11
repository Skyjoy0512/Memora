import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { useState } from 'react';
import { DynamicColorIOS, Platform, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { usePathname } from 'expo-router';
import { CaptureSheet } from '../../src/components/CaptureSheet';
import { HomeComposer } from '../../src/components/HomeComposer';
import { colors as themeColors } from '../../src/theme/tokens';

function isIos26OrHigher(): boolean {
  if (Platform.OS !== 'ios') return false;
  const version = Platform.Version;
  const major = typeof version === 'number' ? version : Number.parseInt(String(version), 10);
  return Number.isFinite(major) && major >= 26;
}

export default function TabLayout() {
  const insets = useSafeAreaInsets();
  const isHome = usePathname() === '/';
  const useNativeAccessory = isIos26OrHigher();
  const [isCaptureSheetOpen, setCaptureSheetOpen] = useState(false);

  return (
    <View style={{ flex: 1 }}>
      <NativeTabs
        minimizeBehavior="onScrollDown"
        tintColor={DynamicColorIOS({
          dark: themeColors.dark.accent,
          light: themeColors.light.accent,
        })}
        labelStyle={{
          fontSize: 11,
          fontWeight: '600',
        }}
      >
        <NativeTabs.Trigger name="index">
          <NativeTabs.Trigger.Icon
            sf={{ default: 'house', selected: 'house.fill' }}
            md={{ default: 'home', selected: 'home' }}
          />
          <NativeTabs.Trigger.Label>ホーム</NativeTabs.Trigger.Label>
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="tasks">
          <NativeTabs.Trigger.Icon
            sf={{ default: 'checkmark.circle', selected: 'checkmark.circle.fill' }}
            md={{ default: 'task_alt', selected: 'task_alt' }}
          />
          <NativeTabs.Trigger.Label>タスク</NativeTabs.Trigger.Label>
        </NativeTabs.Trigger>
        <NativeTabs.Trigger
          disabled
          listeners={{ tabPress: () => setCaptureSheetOpen(true) }}
          name="capture"
          unstable_nativeProps={{ tabBarItemAccessibilityLabel: '録音メニューを開く' }}
        >
          <NativeTabs.Trigger.Icon
            sf={{ default: 'plus', selected: 'plus' }}
            md={{ default: 'add', selected: 'add' }}
          />
          <NativeTabs.Trigger.Label hidden>録音</NativeTabs.Trigger.Label>
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="ask-ai">
          <NativeTabs.Trigger.Icon
            sf={{ default: 'sparkles', selected: 'sparkles' }}
            md={{ default: 'auto_awesome', selected: 'auto_awesome' }}
          />
          <NativeTabs.Trigger.Label>AI</NativeTabs.Trigger.Label>
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="settings">
          <NativeTabs.Trigger.Icon
            sf={{ default: 'gearshape', selected: 'gearshape.fill' }}
            md={{ default: 'settings', selected: 'settings' }}
          />
          <NativeTabs.Trigger.Label>設定</NativeTabs.Trigger.Label>
        </NativeTabs.Trigger>
        {useNativeAccessory && isHome ? (
          <NativeTabs.BottomAccessory>
            <HomeComposer />
          </NativeTabs.BottomAccessory>
        ) : null}
      </NativeTabs>
      <CaptureSheet isOpen={isCaptureSheetOpen} onClose={() => setCaptureSheetOpen(false)} />
      {!useNativeAccessory && isHome ? (
        <View
          pointerEvents="box-none"
          style={[styles.composerOverlay, { bottom: insets.bottom + 57 }]}
        >
          <HomeComposer />
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  composerOverlay: {
    left: 0,
    position: 'absolute',
    right: 0,
    zIndex: 90,
  },
});
