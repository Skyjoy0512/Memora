import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { DynamicColorIOS, Platform, StyleSheet, View, useColorScheme } from 'react-native';
import { useTabBarClearance } from '../../src/components/useTabBarClearance';
import { usePathname, useRouter } from 'expo-router';
import { CaptureSheet } from '../../src/components/CaptureSheet';
import { useCaptureFlow } from '../../src/features/capture/CaptureFlowProvider';
import { AskEntryBar } from '../../src/components/AskEntryBar';
import { colors as themeColors } from '../../src/theme/tokens';

// DynamicColorIOS は iOS 専用で、react-native-web / Android には存在しない。
// ガードなしで呼ぶと web が起動時にクラッシュする。
// 非 iOS では useColorScheme() で解決済みの静的な色を返す。
function useTabTint(): string | ReturnType<typeof DynamicColorIOS> {
  const scheme = useColorScheme();
  if (Platform.OS === 'ios') {
    return DynamicColorIOS({
      dark: themeColors.dark.accent,
      light: themeColors.light.accent,
    });
  }
  return scheme === 'dark' ? themeColors.dark.accent : themeColors.light.accent;
}

function isIos26OrHigher(): boolean {
  if (Platform.OS !== 'ios') return false;
  const version = Platform.Version;
  const major = typeof version === 'number' ? version : Number.parseInt(String(version), 10);
  return Number.isFinite(major) && major >= 26;
}

export default function TabLayout() {
  const tabBarClearance = useTabBarClearance();
  const router = useRouter();
  const pathname = usePathname();
  const isHome = pathname === '/';
  const useNativeAccessory = isIos26OrHigher();
  const capture = useCaptureFlow();
  const tabTint = useTabTint();

  return (
    <View style={{ flex: 1 }}>
      <NativeTabs
        minimizeBehavior="onScrollDown"
        tintColor={tabTint}
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
          <NativeTabs.Trigger.Label>記録</NativeTabs.Trigger.Label>
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
          listeners={{ tabPress: () => capture.openCaptureMenu() }}
          name="capture"
          unstable_nativeProps={{ tabBarItemAccessibilityLabel: '録音メニューを開く' }}
        >
          <NativeTabs.Trigger.Icon
            sf={{ default: 'plus', selected: 'plus' }}
            md={{ default: 'add', selected: 'add' }}
          />
          {/* ラベルを隠すと、アイコンを描けないプラットフォーム（web など）で
              タブが見えなくなる。プロトタイプの録音FABに当たる導線なので必ず出す。 */}
          <NativeTabs.Trigger.Label>録音</NativeTabs.Trigger.Label>
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
            <AskEntryBar onPress={() => router.push('/ask-ai')} />
          </NativeTabs.BottomAccessory>
        ) : null}
      </NativeTabs>
      <CaptureSheet isOpen={capture.isCaptureMenuOpen} onClose={capture.closeCaptureMenu} />
      {!useNativeAccessory && isHome ? (
        <View
          pointerEvents="box-none"
          style={[styles.composerOverlay, { bottom: tabBarClearance }]}
        >
          <AskEntryBar onPress={() => router.push('/ask-ai')} />
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
