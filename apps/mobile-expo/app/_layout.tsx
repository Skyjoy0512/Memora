/// <reference types="expo/types" />

import type { ComponentProps } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { BottomSheetModalProvider } from '@gorhom/bottom-sheet';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { HeroUINativeProvider } from 'heroui-native/provider';
import { useFonts } from 'expo-font';
import {
  IBMPlexSansJP_300Light,
  IBMPlexSansJP_400Regular,
  IBMPlexSansJP_500Medium,
  IBMPlexSansJP_600SemiBold,
} from '@expo-google-fonts/ibm-plex-sans-jp';
import {
  Inter_300Light,
  Inter_400Regular,
  Inter_500Medium,
  Inter_600SemiBold,
} from '@expo-google-fonts/inter';
import {
  IBMPlexMono_400Regular,
  IBMPlexMono_500Medium,
} from '@expo-google-fonts/ibm-plex-mono';
import '../global.css';
import { colors, fonts } from '../src/design/tokens';
import { HomeViewStateProvider } from '../src/features/home/HomeViewState';
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
  // デザインシステム v0.6。トークン（src/theme/tokens.ts の fontFamily）が
  // これらの名前を直接参照するので、ロード前に描画するとフォント未解決の
  // まま初期レイアウトが確定してしまう。ロード完了までは何も描かない。
  const [fontsLoaded, fontError] = useFonts({
    IBMPlexSansJP_300Light,
    IBMPlexSansJP_400Regular,
    IBMPlexSansJP_500Medium,
    IBMPlexSansJP_600SemiBold,
    Inter_300Light,
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
    IBMPlexMono_400Regular,
    IBMPlexMono_500Medium,
  });

  // fontError のときは System フォントで描画を続ける（起動を止めない）
  if (!fontsLoaded && !fontError) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <HeroUINativeProvider config={heroUIConfig}>
        <BottomSheetModalProvider>
          <CaptureFlowProvider>
            <HomeViewStateProvider>
              <StatusBar style="dark" />
              <Stack
                screenOptions={{
                  contentStyle: { backgroundColor: colors.canvas },
                  headerShadowVisible: false,
                  headerTintColor: colors.text,
                  headerTitleStyle: { ...fonts.sans.semibold },
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
            </HomeViewStateProvider>
          </CaptureFlowProvider>
        </BottomSheetModalProvider>
      </HeroUINativeProvider>
    </GestureHandlerRootView>
  );
}
