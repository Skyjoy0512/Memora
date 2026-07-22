import { StyleSheet, Text, View } from 'react-native';
import { colors, spacing, textStyles } from '../design/tokens';

type DateSeparatorProps = {
  date: string;
};

export function DateSeparator({ date }: DateSeparatorProps) {
  return (
    <View style={dsStyles.container} accessibilityRole="header">
      <View style={dsStyles.line} />
      <Text style={dsStyles.label}>{date}</Text>
      <View style={dsStyles.line} />
    </View>
  );
}

const dsStyles = StyleSheet.create({
  container: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    paddingVertical: spacing.xs,
  },
  line: {
    backgroundColor: colors.borderLight,
    flex: 1,
    height: 1,
  },
  label: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
});
