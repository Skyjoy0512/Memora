import { Pressable, StyleSheet, Text, View } from 'react-native';
import { AppIcon } from './AppIcon';
import { StatusPill } from './StatusPill';
import { colors, radius, spacing, shadow, textStyles } from '../design/tokens';
import type { AudioFile } from '../types/memora';
import { formatRecordedAt } from '../utils/formatRecordedAt';

type FileCardProps = {
  file: AudioFile;
  onPress: () => void;
  onMore?: () => void;
  showSummary?: boolean;
};

export function FileCard({
  file,
  onPress,
  onMore,
  showSummary = true,
}: FileCardProps) {
  return (
    <Pressable
      accessibilityLabel={`${file.title}を開く`}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        fcStyles.card,
        pressed && fcStyles.pressed,
      ]}
    >
      <View style={fcStyles.icon}>
        <AppIcon
          color={colors.textSecondary}
          name={file.source === 'iPhone' ? 'mic-outline' : 'document-outline'}
          size={16}
        />
      </View>

      <View style={fcStyles.body}>
        <Text numberOfLines={1} style={fcStyles.title}>
          {file.title}
        </Text>
        <Text numberOfLines={1} style={fcStyles.meta}>
          {formatRecordedAt(file.recordedAt)} · {file.duration}
        </Text>
        {showSummary && file.summary ? (
          <Text numberOfLines={1} style={fcStyles.summary}>
            {file.summary}
          </Text>
        ) : null}
      </View>

      <StatusPill status={file.status} />

      {onMore ? (
        <Pressable
          accessibilityLabel="その他の操作"
          accessibilityRole="button"
          hitSlop={8}
          onPress={onMore}
          style={({ pressed }) => [
            fcStyles.more,
            pressed && fcStyles.morePressed,
          ]}
        >
          <Text style={fcStyles.moreText}>⋯</Text>
        </Pressable>
      ) : null}
    </Pressable>
  );
}

const fcStyles = StyleSheet.create({
  card: {
    alignItems: 'flex-start',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.md,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 72,
    padding: spacing.md,
    ...shadow.card,
  },
  pressed: {
    opacity: 0.76,
    transform: [{ scale: 0.97 }],
  },
  icon: {
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.sm,
    flexShrink: 0,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  body: {
    flex: 1,
    minWidth: 0,
  },
  title: {
    color: colors.text,
    ...textStyles.bodyBold,
  },
  meta: {
    color: colors.textSecondary,
    marginTop: 1,
    ...textStyles.caption,
  },
  summary: {
    color: colors.textSecondary,
    marginTop: 4,
    ...textStyles.footnote,
  },
  more: {
    alignItems: 'center',
    flexShrink: 0,
    height: 44,
    justifyContent: 'center',
    margin: -6,
    width: 44,
  },
  morePressed: {
    opacity: 0.5,
  },
  moreText: {
    color: colors.textTertiary,
    ...textStyles.callout,
  },
});
