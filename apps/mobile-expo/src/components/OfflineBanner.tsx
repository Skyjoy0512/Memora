import { StyleSheet, Text, View } from 'react-native';
import { AppIcon } from './AppIcon';
import { colors, radius, spacing, textStyles } from '../design/tokens';

type OfflineBannerProps = {
  message?: string;
};

export function OfflineBanner({
  message = 'オフライン — 端末内の記録のみ表示されます',
}: OfflineBannerProps) {
  return (
    <View style={obStyles.banner} accessibilityRole="alert" accessibilityLiveRegion="polite">
      <AppIcon color={colors.warning} name="warning-outline" size={16} />
      <Text style={obStyles.text}>{message}</Text>
    </View>
  );
}

const obStyles = StyleSheet.create({
  banner: {
    alignItems: 'center',
    backgroundColor: colors.warningSoft,
    borderRadius: radius.sm,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  text: {
    color: colors.text,
    flex: 1,
    ...textStyles.footnoteBold,
  },
});
