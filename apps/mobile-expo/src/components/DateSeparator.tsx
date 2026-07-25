import { StyleSheet, View } from 'react-native';
import { Separator, Text } from 'heroui-native';
import { spacing, textStyles } from '../design/tokens';

type DateSeparatorProps = {
  date: string;
};

export function DateSeparator({ date }: DateSeparatorProps) {
  return (
    <View style={dsStyles.container} accessibilityRole="header">
      <Separator style={dsStyles.line} />
      <Text style={dsStyles.label}>{date}</Text>
      <Separator style={dsStyles.line} />
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
    flex: 1,
  },
  label: {
    ...textStyles.caption,
  },
});
