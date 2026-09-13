import { Platform } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

/**
 * タブバーが覆う高さ。下端に置くもの（Ask AI のドック、浮かぶ入口バー、
 * リストの末尾）はこの値だけ空ける。
 *
 * 以前は画面ごとに 57 / 60 / 76 / 112 とバラバラの数値が書かれていて、
 * Ask AI のドックがタブバーに潜り込んでいた。値はここだけで持つ。
 *
 * - iOS 26 / Android: 浮動タブバーの実寸（約56pt）＋ ホームインジケータの inset
 * - web: expo-router の web 実装が `bottom: 16px` に 40px のピルを置く（global.css で下端へ寄せている）
 */
const NATIVE_TAB_BAR_HEIGHT = 56;
const WEB_TAB_BAR_CLEARANCE = 64;

export function useTabBarClearance(): number {
  const insets = useSafeAreaInsets();
  if (Platform.OS === 'web') return WEB_TAB_BAR_CLEARANCE;
  return insets.bottom + NATIVE_TAB_BAR_HEIGHT;
}
