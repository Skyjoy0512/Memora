import { Pressable, StyleSheet, Text, View } from 'react-native';
import { AppIcon } from './AppIcon';
import { NumericText } from './NumericText';
import { StatusPill } from './StatusPill';
import { colors, spacing, textStyles } from '../design/tokens';
import type { AudioFile } from '../types/memora';
import { formatRecordedAt } from '../utils/formatRecordedAt';

type FileCardProps = {
  file: AudioFile;
  onPress: () => void;
  onMore?: () => void;
  showSummary?: boolean;
};

/** 状態バッジを出さない＝読める記録。それ以外は行の右端で状態を明示する。 */
const settledStatuses = new Set(['ready', 'summarized', 'completed']);

/**
 * Open Design v2 の `.record-row`。
 * 情報の順序は 収録時刻・再生時間（mono）→ タイトル → 要約 2行。
 * カードや角丸は使わず、行の区切りは下罫線だけで表す。
 */
export function FileCard({ file, onPress, onMore, showSummary = true }: FileCardProps) {
  const isSettled = settledStatuses.has(file.status);

  return (
    <View style={fcStyles.row}>
      <Pressable
        accessibilityLabel={`${file.title}を開く`}
        accessibilityRole="button"
        onPress={onPress}
        style={({ pressed }) => [fcStyles.main, pressed && fcStyles.pressed]}
      >
        <NumericText numberOfLines={1} style={fcStyles.meta}>
          {`${formatRecordedAt(file.recordedAt)} · ${file.duration}`}
        </NumericText>
        <Text numberOfLines={1} style={fcStyles.title}>
          {file.title}
        </Text>
        {showSummary && file.summary ? (
          <Text numberOfLines={2} style={fcStyles.summary}>
            {file.summary}
          </Text>
        ) : null}
      </Pressable>

      <View style={fcStyles.trailing}>
        {isSettled ? null : <StatusPill status={file.status} variant="outline" />}
        {onMore ? (
          <Pressable
            accessibilityLabel="その他の操作"
            accessibilityRole="button"
            hitSlop={4}
            onPress={onMore}
            style={({ pressed }) => [fcStyles.more, pressed && fcStyles.pressed]}
          >
            <AppIcon color={colors.textSecondary} name="ellipsis-horizontal" size={20} />
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

const fcStyles = StyleSheet.create({
  row: {
    alignItems: 'flex-start',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: spacing.xs,
    paddingVertical: spacing.md,
  },
  main: {
    flex: 1,
    minWidth: 0,
  },
  pressed: {
    opacity: 0.62,
  },
  meta: {
    color: colors.textSecondary,
    ...textStyles.caption,
  },
  title: {
    color: colors.text,
    marginTop: spacing.xxs,
    ...textStyles.rowTitle,
  },
  summary: {
    color: colors.textSecondary,
    marginTop: spacing.xxs,
    ...textStyles.footnote,
  },
  trailing: {
    alignItems: 'flex-end',
    flexShrink: 0,
    gap: spacing.xs,
  },
  more: {
    alignItems: 'center',
    height: 36,
    justifyContent: 'center',
    marginRight: -spacing.xs,
    width: 36,
  },
});
