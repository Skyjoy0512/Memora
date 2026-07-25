import { StyleSheet } from 'react-native';
import { Chip } from 'heroui-native';
import type { AudioStatus } from '../types/memora';

const statusCopy: Record<AudioStatus, string> = {
  queued: '文字起こし待ち',
  ready: '文字起こし済み',
  summarized: '要約済み',
  transcribing: '文字起こし中',
  failed: '確認が必要',
};

const statusColors: Record<AudioStatus, 'default' | 'success' | 'warning' | 'danger'> = {
  queued: 'default',
  ready: 'default',
  summarized: 'success',
  transcribing: 'warning',
  failed: 'danger',
};

const fallbackCopy = '処理待ち';
const fallbackTone = 'default';

export function StatusPill({ status }: { status: AudioStatus | string }) {
  const tone = statusColors[status as AudioStatus] ?? fallbackTone;
  const copy = statusCopy[status as AudioStatus] ?? fallbackCopy;
  return (
    <Chip color={tone} size="sm" style={styles.pill} variant="soft">
      {copy}
    </Chip>
  );
}

const styles = StyleSheet.create({
  pill: {
    alignSelf: 'flex-start',
  },
});
