import { AppIcon } from './AppIcon';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing } from '../design/tokens';
import type { AudioFile } from '../types/memora';
import { StatusPill } from './StatusPill';

type Props = {
  file: AudioFile;
  onDelete?: () => void;
  onPress: () => void;
};

export function AudioFileCard({ file, onDelete, onPress }: Props) {
  return (
    <View style={styles.card}>
      <View style={styles.topRow}>
        <View style={styles.iconWrap}>
          <AppIcon color={colors.accent} name="mic-outline" size={20} />
        </View>
        <View style={styles.topActions}>
          <StatusPill status={file.status} />
          {onDelete ? (
            <Pressable
              accessibilityLabel={`${file.title} を削除`}
              accessibilityRole="button"
              onPress={onDelete}
              style={({ pressed }) => [styles.deleteAction, pressed && styles.deleteActionPressed]}
            >
              <AppIcon color={colors.danger} name="trash-outline" size={17} />
            </Pressable>
          ) : null}
        </View>
      </View>
      <Pressable
        accessibilityLabel={`${file.title} を開く`}
        accessibilityRole="button"
        onPress={onPress}
        style={({ pressed }) => [styles.cardBody, pressed && styles.cardPressed]}
      >
        <View style={styles.textBlock}>
          <Text numberOfLines={2} style={styles.title}>
            {file.title}
          </Text>
          <Text style={styles.meta}>
            {file.project} · {file.source} · {file.duration}
          </Text>
        </View>
        <Text numberOfLines={2} style={styles.summary}>
          {file.summary}
        </Text>
        <View style={styles.footer}>
          <Text style={styles.date}>{file.recordedAt}</Text>
          <AppIcon color={colors.textSubtle} name="chevron-forward" size={18} />
        </View>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    gap: spacing.sm,
    paddingVertical: spacing.md,
  },
  cardBody: {
    gap: spacing.md,
  },
  topActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  deleteAction: {
    alignItems: 'center',
    backgroundColor: colors.dangerSoft,
    borderRadius: radius.pill,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  deleteActionPressed: {
    opacity: 0.72,
  },
  cardPressed: {
    opacity: 0.86,
    transform: [{ translateY: 1 }],
  },
  topRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  iconWrap: {
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.sm,
    height: 30,
    justifyContent: 'center',
    width: 30,
  },
  textBlock: {
    gap: 6,
  },
  title: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '500',
    letterSpacing: 0,
    lineHeight: 25,
  },
  meta: {
    color: colors.textMuted,
    fontSize: 12,
    fontWeight: '400',
  },
  summary: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  footer: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  date: {
    color: colors.textSubtle,
    fontSize: 12,
    fontWeight: '700',
  },
});
