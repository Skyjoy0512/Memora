import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { DynamicColorIOS, View } from 'react-native';
import { CaptureFab } from '../../src/components/CaptureFab';
import { colors as themeColors } from '../../src/theme/tokens';

export default function TabLayout() {
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
      </NativeTabs>
      <CaptureFab />
    </View>
  );
}
