import { Tabs } from 'expo-router';
import { V6FloatingTabBar } from '../../src/components/V6FloatingTabBar';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: { backgroundColor: 'transparent', borderTopWidth: 0, elevation: 0, position: 'absolute' },
      }}
      tabBar={(props) => <V6FloatingTabBar {...props} />}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'ホーム',
        }}
      />
      <Tabs.Screen name="tasks" options={{ title: 'タスク' }} />
      <Tabs.Screen
        name="ask-ai"
        options={{
          title: 'Ask',
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: '設定',
        }}
      />
    </Tabs>
  );
}
