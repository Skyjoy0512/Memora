import { AppIcon } from './AppIcon';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View, type LayoutChangeEvent, type GestureResponderEvent } from 'react-native';
import { colors } from '../design/tokens';
import type { PlaybackStatusDTO } from '../native/MemoraNative.types';

type Props = {
  onCycleRate: () => void;
  onSeek: (position: number) => void;
  onTogglePlay: () => void;
  status: PlaybackStatusDTO;
};

function formatTime(seconds: number) {
  const safeSeconds = Number.isFinite(seconds) ? Math.max(0, seconds) : 0;
  const totalSeconds = Math.floor(safeSeconds);
  return `${String(Math.floor(totalSeconds / 60)).padStart(2, '0')}:${String(totalSeconds % 60).padStart(2, '0')}`;
}

export function PlayerBar({ onCycleRate, onSeek, onTogglePlay, status }: Props) {
  const [trackWidth, setTrackWidth] = useState(0);
  const ratio = status.duration > 0 ? Math.min(status.position / status.duration, 1) : 0;

  function handleLayout(event: LayoutChangeEvent) {
    setTrackWidth(event.nativeEvent.layout.width);
  }

  function handleSeekPress(event: GestureResponderEvent) {
    if (trackWidth <= 0 || status.duration <= 0) return;
    const pct = Math.max(0, Math.min(event.nativeEvent.locationX / trackWidth, 1));
    onSeek(pct * status.duration);
  }

  return (
    <View style={styles.wrap}>
      <View style={styles.row}>
        <Pressable accessibilityLabel={status.isPlaying ? '一時停止' : '再生'} accessibilityRole="button" onPress={onTogglePlay} style={({ pressed }) => [styles.playButton, pressed && styles.pressed]}>
          <AppIcon color={colors.text} name={status.isPlaying ? 'pause' : 'play'} size={13} weight="Filled" />
        </Pressable>
        <Text style={styles.time}>
          {formatTime(status.position)} / {formatTime(status.duration)}
        </Text>
        <View style={styles.spacer} />
        <Pressable accessibilityLabel={`再生速度を変更、現在 ${status.rate}倍速`} accessibilityRole="button" onPress={onCycleRate} style={({ pressed }) => [styles.rateButton, pressed && styles.pressed]}>
          <Text style={styles.rateText}>{status.rate}x</Text>
        </Pressable>
      </View>

      <Pressable accessibilityLabel={`再生位置、${formatTime(status.position)} / ${formatTime(status.duration)}`} accessibilityRole="button" onLayout={handleLayout} onPress={handleSeekPress} style={styles.trackWrap}>
        <View style={styles.track}>
          <View style={[styles.trackFill, { width: `${ratio * 100}%` }]} />
        </View>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    borderBottomColor: colors.surfaceAlt,
    borderBottomWidth: 1,
    gap: 8,
    paddingBottom: 10,
    paddingTop: 6,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
  },
  playButton: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: 19,
    borderWidth: 1,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  time: {
    color: colors.text,
    fontSize: 13,
    fontVariant: ['tabular-nums'],
    fontWeight: '500',
  },
  spacer: { flex: 1 },
  rateButton: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 8,
    paddingHorizontal: 9,
    paddingVertical: 5,
  },
  rateText: {
    color: colors.text,
    fontSize: 11.5,
    fontWeight: '600',
  },
  pressed: { opacity: 0.74, transform: [{ scale: 0.93 }] },
  trackWrap: {
    height: 12,
    justifyContent: 'center',
  },
  track: {
    backgroundColor: '#EEEEEE',
    borderRadius: 2,
    height: 3,
    overflow: 'hidden',
  },
  trackFill: {
    backgroundColor: colors.text,
    height: '100%',
  },
});
