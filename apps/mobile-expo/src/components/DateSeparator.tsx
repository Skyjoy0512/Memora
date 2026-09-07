import { StyleSheet, Text, View } from 'react-native';
import { colors, spacing, textStyles } from '../design/tokens';

type DateSeparatorProps = {
  date: string;
};

/**
 * Open Design v2 の `.date-label`。ラベルの右側を罫線が埋め、
 * 日付グループの切れ目を横罫として示す。
 */
export function DateSeparator({ date }: DateSeparatorProps) {
  return (
    <View accessibilityRole="header" style={dsStyles.container}>
      <Text style={dsStyles.label}>{date}</Text>
      <View style={dsStyles.rule} />
    </View>
  );
}

const dsStyles = StyleSheet.create({
  container: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    paddingTop: spacing.xl,
  },
  label: {
    color: colors.textSecondary,
    ...textStyles.footnote,
  },
  rule: {
    backgroundColor: colors.border,
    flex: 1,
    height: 1,
  },
});
