import type { ReactNode } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Surface } from 'heroui-native';
import { colors, spacing, textStyles } from '../design/tokens';

type Props = {
  title: string;
  children: ReactNode;
  action?: ReactNode;
};

export function Section({ title, children, action }: Props) {
  return (
    <View style={styles.section}>
      <Surface style={styles.header} variant="transparent">
        <Text style={styles.title}>{title}</Text>
        {action}
      </Surface>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  section: {
    gap: spacing.md,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  title: {
    color: colors.text,
    ...textStyles.captionBold,
    letterSpacing: 0,
    textTransform: 'uppercase',
  },
});
