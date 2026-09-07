import type { ReactElement, ReactNode } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, View, type RefreshControlProps } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing, textStyles } from '../design/tokens';
import { useTabBarClearance } from './useTabBarClearance';
import { colors as themeColors, screenMargin } from '../theme/tokens';

type Props = {
  title?: string;
  titleContent?: ReactNode;
  titleVariant?: 'home' | 'screen';
  subtitle?: string;
  topRow?: ReactNode;
  headerLeading?: ReactNode;
  headerAccessory?: ReactNode;
  /** ヘッダー下端に貼り付く要素（記録詳細のタブなど）。ヘッダーの面の内側に入る。 */
  headerBottom?: ReactNode;
  /**
   * `inverse` は Open Design v2 の `.file-header`。記録詳細だけがヘッダーを暗転させ、
   * 「この画面は音声という正本を扱っている」ことを面で示す。
   */
  headerVariant?: 'default' | 'inverse';
  /** タブバーの上に載る画面かどうか。スタック画面（記録詳細など）は false。 */
  withinTabs?: boolean;
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
  headerBottom,
  headerVariant = 'default',
  withinTabs = true,
  footerAccessory,
  children,
  refreshControl,
  list,
}: Props) {
  const isInverse = headerVariant === 'inverse';
  // 下端の余白。footerAccessory はスクロール領域の下に積まれて自分の高さを持つので、
  // その場合はタブバーぶんを二重に足さない。タブの外（スタック画面）も足さない。
  const tabBarClearance = useTabBarClearance();
  const contentBottomPadding = footerAccessory
    ? spacing.xl
    : (withinTabs ? tabBarClearance : 0) + spacing.xl;

  const headerElement = (
    <View style={[styles.header, isInverse && styles.headerInverse]}>
      {topRow}
      <View style={styles.titleRow}>
        {headerLeading}
        {titleContent ?? (title ? <Text numberOfLines={1} style={[styles.title, titleVariant === 'home' && styles.homeTitle, isInverse && styles.titleInverse]}>{title}</Text> : null)}
        {headerAccessory}
      </View>
      {subtitle ? <Text style={[styles.subtitle, isInverse && styles.subtitleInverse]}>{subtitle}</Text> : null}
      {headerBottom}
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
        ) : isInverse ? (
          <>
            {headerElement}
            <ScrollView
              contentContainerStyle={[styles.content, { paddingBottom: contentBottomPadding }]}
              keyboardShouldPersistTaps="handled"
              refreshControl={refreshControl}
              showsVerticalScrollIndicator={false}
            >
              {children}
            </ScrollView>
          </>
        ) : (
          <ScrollView
            contentContainerStyle={[styles.content, { paddingBottom: contentBottomPadding }]}
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
    paddingHorizontal: screenMargin.compact,
    // web は safe-area inset が 0 で見出しが上端に貼り付くため、
    // プロトタイプの `padding-top: max(48px, safe + 16px)` に相当する余白を足す。
    paddingTop: Platform.OS === 'web' ? spacing.xl : spacing.xs,
  },
  listHeaderArea: {
    gap: spacing.lg,
    paddingHorizontal: screenMargin.compact,
    paddingTop: Platform.OS === 'web' ? spacing.xl : spacing.xs,
  },
  listBody: {
    flex: 1,
  },
  header: {
    gap: spacing.sm,
  },
  headerInverse: {
    backgroundColor: themeColors.dark.canvas,
    borderBottomColor: themeColors.dark.border,
    borderBottomWidth: 1,
    paddingBottom: spacing.sm,
    paddingHorizontal: screenMargin.compact,
    paddingTop: Platform.OS === 'web' ? spacing.lg : spacing.xs,
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
  titleInverse: {
    color: themeColors.dark.foregroundPrimary,
  },
  subtitleInverse: {
    color: themeColors.dark.foregroundSecondary,
  },
  subtitle: {
    color: colors.textSecondary,
    ...textStyles.body,
  },
});
