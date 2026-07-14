import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { BottomSheetModalProvider } from '@gorhom/bottom-sheet';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { colors } from '../src/design/tokens';
import { CaptureFlowProvider } from '../src/features/capture/CaptureFlowProvider';

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <BottomSheetModalProvider>
        <CaptureFlowProvider>
          <StatusBar style="dark" />
          <Stack
            screenOptions={{
              contentStyle: { backgroundColor: colors.canvas },
              headerShadowVisible: false,
              headerTintColor: colors.text,
              headerTitleStyle: { fontWeight: '700' },
            }}
          >
            <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
            <Stack.Screen name="auth" options={{ headerShown: false, presentation: 'card' }} />
            <Stack.Screen
              name="file/[id]"
              options={{
                headerShown: false,
                presentation: 'card',
              }}
            />
            <Stack.Screen name="preview" options={{ title: 'Preview Index' }} />
            <Stack.Screen name="dev-fonts" options={{ headerShown: false, presentation: 'modal' }} />
          </Stack>
        </CaptureFlowProvider>
      </BottomSheetModalProvider>
    </GestureHandlerRootView>
  );
}
