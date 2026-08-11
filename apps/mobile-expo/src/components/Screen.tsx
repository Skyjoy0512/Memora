import type { ReactElement, ReactNode } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, View, type RefreshControlProps } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing, textStyles } from '../design/tokens';

type Props = {
  title?: string;
  titleContent?: ReactNode;
  titleVariant?: 'home' | 'screen';
  subtitle?: string;
  topRow?: ReactNode;
  headerLeading?: ReactNode;
  headerAccessory?: ReactNode;
  footerAccessory?: ReactNode;
  children: ReactNode;
  refreshControl?: ReactElement<RefreshControlProps>;
  /** When provided, the header stays fixed and this scroll body (e.g. FlashList) replaces the built-in ScrollView. */
  list?: ReactElement;
};

export function Screen({
  title,
  titleContent,
  titleVariant = 'screen',
  subtitle,
  topRow,
  headerLeading,
  headerAccessory,
  footerAccessory,
  children,
  refreshControl,
  list,
}: Props) {
  const headerElement = (
    <View style={styles.header}>
      {topRow}
      <View style={styles.titleRow}>
        {headerLeading}
        {titleContent ?? (title ? <Text numberOfLines={1} style={[styles.title, titleVariant === 'home' && styles.homeTitle]}>{title}</Text> : null)}
        {headerAccessory}
      </View>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
    </View>
  );

  return (
    <SafeAreaView edges={['top']} style={styles.safeArea}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.flex}
      >
        {list ? (
          <>
            <View style={styles.listHeaderArea}>
              {headerElement}
              {children}
            </View>
            <View style={styles.listBody}>{list}</View>
          </>
        ) : (
          <ScrollView
            contentContainerStyle={styles.content}
            keyboardShouldPersistTaps="handled"
            refreshControl={refreshControl}
            showsVerticalScrollIndicator={false}
          >
            {headerElement}
            {children}
          </ScrollView>
        )}
        {footerAccessory}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: colors.canvas,
    flex: 1,
  },
  flex: {
    flex: 1,
  },
  content: {
    gap: spacing.lg,
    paddingBottom: 112,
    paddingHorizontal: 18,
    paddingTop: 10,
  },
  listHeaderArea: {
    gap: spacing.lg,
    paddingHorizontal: 18,
    paddingTop: 10,
  },
  listBody: {
    flex: 1,
  },
  header: {
    gap: spacing.sm,
  },
  titleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  title: {
    color: colors.text,
    flex: 1,
    ...textStyles.screenTitle,
  },
  homeTitle: {
    ...textStyles.screenTitle,
  },
  subtitle: {
    color: colors.textSecondary,
    ...textStyles.body,
  },
});
