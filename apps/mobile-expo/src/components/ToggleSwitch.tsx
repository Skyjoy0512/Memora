import { Pressable, StyleSheet, View } from 'react-native';
import { colors, radius, spacing } from '../design/tokens';

/**
 * Open Design v2 の `.switch`。
 * 角丸のトラックではなく 32×18 の矩形で、つまみだけが円。オンは前景色で塗る。
 * 44pt のタップ領域の中に描く。
 */
export function ToggleSwitch({
  accessibilityLabel,
  isOn,
  onToggle,
}: {
  accessibilityLabel: string;
  isOn: boolean;
  onToggle: (next: boolean) => void;
}) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="switch"
      accessibilityState={{ checked: isOn }}
      onPress={() => onToggle(!isOn)}
      style={styles.tap}
    >
      <View style={[styles.track, isOn && styles.trackOn]}>
        <View style={[styles.knob, isOn && styles.knobOn]} />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  tap: {
    alignItems: 'center',
    height: 44,
    justifyContent: 'center',
    marginRight: -spacing.xs,
    width: 44,
  },
  track: {
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    height: 18,
    justifyContent: 'center',
    paddingHorizontal: 1,
    width: 32,
  },
  trackOn: {
    backgroundColor: colors.accent,
    borderColor: colors.accent,
  },
  knob: {
    backgroundColor: colors.textSecondary,
    borderRadius: radius.circle,
    height: 14,
    width: 14,
  },
  knobOn: {
    backgroundColor: colors.surface,
    transform: [{ translateX: 14 }],
  },
});
