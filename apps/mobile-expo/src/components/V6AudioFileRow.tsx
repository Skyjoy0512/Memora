import { AppIcon } from './AppIcon';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors } from '../design/tokens';
import type { AudioFile } from '../types/memora';

type Props = {
  file: AudioFile;
  onOpen: () => void;
  onMore?: () => void;
  onRetry?: () => void;
};

export function V6AudioFileRow({ file, onOpen, onMore, onRetry }: Props) {
  const isProcessing = file.status === 'transcribing';
  const isFailed = file.status === 'failed';
  const displayTitle = file.title.startsWith('native-recording-') ? '新しい録音' : file.title;
  const displaySummary = file.summary?.includes('Recorded by the native Expo module')
    ? undefined
    : file.summary;
  const meta = isFailed
    ? '文字起こしに失敗しました'
    : `${file.duration} ・ ${file.status === 'summarized' ? '要約済み' : isProcessing ? '解析中' : '処理待ち'}`;

  return (
    <View style={styles.row}>
      <Pressable accessibilityRole="button" onPress={onOpen} style={({ pressed }) => [styles.openArea, pressed && styles.pressed]}>
        <View style={styles.copy}>
          <Text numberOfLines={1} style={styles.title}>{displayTitle}</Text>
          <Text style={[styles.meta, isFailed && styles.failedMeta]}>{meta}</Text>
        </View>
        {isProcessing ? <View style={styles.progressTrack}><View style={styles.progressValue} /></View> : null}
        {displaySummary ? <Text numberOfLines={2} style={styles.summary}>{displaySummary}</Text> : null}
      </Pressable>
      {isFailed ? (
        onRetry ? <Pressable accessibilityRole="button" hitSlop={10} onPress={onRetry} style={styles.trailingAction}>
          <Text style={styles.retryText}>再試行</Text>
        </Pressable> : <View accessibilityState={{ disabled: true }} style={styles.trailingAction}>
          <Text style={styles.retryUnavailableText}>準備中</Text>
        </View>
      ) : isProcessing || !onMore ? null : (
        <Pressable accessibilityLabel={`${displayTitle}の操作`} accessibilityRole="button" hitSlop={10} onPress={onMore} style={styles.trailingAction}>
          <AppIcon color={colors.quiet} name="ellipsis-horizontal" size={19} />
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { position: 'relative' },
  openArea: { gap: 6, paddingRight: 40, paddingVertical: 14 },
  pressed: { opacity: 0.76, transform: [{ scale: 0.985 }] },
  copy: { flex: 1, gap: 4 },
  title: { color: colors.ink, fontSize: 15, fontWeight: '500', lineHeight: 20 },
  meta: { color: colors.quiet, fontSize: 12, lineHeight: 16 },
  failedMeta: { color: colors.danger },
  summary: { color: colors.textMutedLight, fontSize: 12.5, lineHeight: 20 },
  trailingAction: { alignItems: 'center', height: 44, justifyContent: 'center', position: 'absolute', right: -7, top: 7, width: 44 },
  retryText: { color: colors.ink, fontSize: 12, fontWeight: '500', textDecorationLine: 'underline' },
  retryUnavailableText: { color: colors.quiet, fontSize: 11, fontWeight: '500' },
  progressTrack: { backgroundColor: colors.paleLine, borderRadius: 99, height: 2, overflow: 'hidden' },
  progressValue: { backgroundColor: colors.ink, borderRadius: 99, height: 2, width: '58%' },
});
