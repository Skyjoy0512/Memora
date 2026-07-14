import { useColorScheme } from 'react-native';
import { colors, darkColors } from './tokens';

/**
 * Returns the active color palette based on the current color scheme.
 * Components should call this at render time to get the correct colors
 * for light or dark mode.
 *
 * Usage:
 *   const colors = useColors();
 *   // colors.canvas, colors.accent, etc.
 */
export function useColors() {
  const scheme = useColorScheme();
  return scheme === 'dark' ? darkColors : colors;
}
