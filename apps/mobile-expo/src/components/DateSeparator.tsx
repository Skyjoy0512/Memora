import { StyleSheet, Text, View } from 'react-native';
import { Separator } from 'heroui-native/separator';
import { colors, spacing, textStyles } from '../design/tokens';

type DateSeparatorProps = {
  date: string;
};

export function DateSeparator({ date }: DateSeparatorProps) {
  return (
    <View style={dsStyles.container} accessibilityRole="header">
      <Text style={dsStyles.label}>{date}</Text>
      <Separator orientation="horizontal" variant="thin" />
    </View>
  );
}

const dsStyles = StyleSheet.create({
  container: {
    gap: spacing.xs,
    paddingTop: spacing.md,
  },
  label: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
});
