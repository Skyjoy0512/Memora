/// <reference types="expo/types" />

import type { ComponentProps } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { BottomSheetModalProvider } from '@gorhom/bottom-sheet';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { HeroUINativeProvider } from 'heroui-native/provider';
import '../global.css';
import { colors } from '../src/design/tokens';
import { CaptureFlowProvider } from '../src/features/capture/CaptureFlowProvider';
import { shouldExposeRoute } from '../src/utils/releaseGate';

const heroUIConfig: NonNullable<ComponentProps<typeof HeroUINativeProvider>['config']> = {
  textProps: {
    allowFontScaling: true,
    maxFontSizeMultiplier: 2,
  },
  textInputProps: {
    allowFontScaling: true,
    maxFontSizeMultiplier: 2,
  },
};

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <HeroUINativeProvider config={heroUIConfig}>
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
              <Stack.Protected guard={shouldExposeRoute('auth', __DEV__)}>
                <Stack.Screen name="auth" options={{ headerShown: false, presentation: 'card' }} />
              </Stack.Protected>
              <Stack.Screen
                name="file/[id]"
                options={{
                  headerShown: false,
                  presentation: 'card',
                }}
              />
              <Stack.Protected guard={shouldExposeRoute('preview', __DEV__)}>
                <Stack.Screen name="preview" options={{ title: 'Preview Index' }} />
              </Stack.Protected>
              <Stack.Protected guard={shouldExposeRoute('dev-fonts', __DEV__)}>
                <Stack.Screen name="dev-fonts" options={{ headerShown: false, presentation: 'modal' }} />
              </Stack.Protected>
            </Stack>
          </CaptureFlowProvider>
        </BottomSheetModalProvider>
      </HeroUINativeProvider>
    </GestureHandlerRootView>
  );
}
