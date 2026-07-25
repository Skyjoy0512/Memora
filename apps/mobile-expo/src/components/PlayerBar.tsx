import { AppIcon } from './AppIcon';
import { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View, useColorScheme } from 'react-native';
import { PressableFeedback } from 'heroui-native/pressable-feedback';
import { Slider } from 'heroui-native/slider';
import { colors, darkColors, radius, spacing, textStyles } from '../design/tokens';
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
  const [seekPosition, setSeekPosition] = useState(status.position);
  const isSeekingRef = useRef(false);
  const palette = useColorScheme() === 'dark' ? darkColors : colors;
  const duration = Math.max(status.duration, 0);

  useEffect(() => {
    if (!isSeekingRef.current) setSeekPosition(status.position);
  }, [status.position]);

  function getValue(value: number | number[]) {
    return Array.isArray(value) ? value[0] ?? 0 : value;
  }

  function handleSeekChange(value: number | number[]) {
    isSeekingRef.current = true;
    setSeekPosition(getValue(value));
  }

  function handleSeekEnd(value: number | number[]) {
    const nextPosition = getValue(value);
    isSeekingRef.current = false;
    setSeekPosition(nextPosition);
    onSeek(nextPosition);
  }

  return (
    <View style={[styles.wrap, { borderBottomColor: palette.separator }]}>
      <View style={styles.row}>
        <PressableFeedback accessibilityLabel={status.isPlaying ? '一時停止' : '再生'} accessibilityRole="button" animation={{ scale: { value: 0.97 } }} onPress={onTogglePlay} style={[styles.playButton, { borderColor: palette.border }]}>
          <AppIcon color={palette.text} name={status.isPlaying ? 'pause' : 'play'} size={13} weight="Filled" />
        </PressableFeedback>
        <Text style={[styles.time, { color: palette.text }]}>
          {formatTime(status.position)} / {formatTime(status.duration)}
        </Text>
        <View style={styles.spacer} />
        <PressableFeedback accessibilityLabel={`再生速度を変更、現在 ${status.rate}倍速`} accessibilityRole="button" animation={{ scale: { value: 0.97 } }} onPress={onCycleRate} style={[styles.rateButton, { backgroundColor: palette.surfaceAlt }]}>
          <Text style={[styles.rateText, { color: palette.text }]}>{status.rate}x</Text>
        </PressableFeedback>
      </View>

      <Slider
        accessibilityLabel={`再生位置、${formatTime(seekPosition)} / ${formatTime(status.duration)}`}
        isDisabled={duration === 0}
        maxValue={duration || 1}
        minValue={0}
        onChange={handleSeekChange}
        onChangeEnd={handleSeekEnd}
        step={0.1}
        style={styles.trackWrap}
        value={Math.min(seekPosition, duration || 1)}
      >
        <Slider.Track style={[styles.track, { backgroundColor: palette.surfaceAlt }]}>
          <Slider.Fill style={[styles.trackFill, { backgroundColor: palette.text }]} />
          <Slider.Thumb styles={{ thumbContainer: { backgroundColor: palette.text } }} />
        </Slider.Track>
      </Slider>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    borderBottomWidth: 1,
    gap: spacing.sm,
    paddingBottom: spacing.md,
    paddingTop: spacing.xs,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  playButton: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: radius.pill,
    borderWidth: 1,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  time: {
    color: colors.text,
    fontVariant: ['tabular-nums'],
    ...textStyles.footnote,
  },
  spacer: { flex: 1 },
  rateButton: {
    borderRadius: radius.sm,
    minHeight: 44,
    minWidth: 44,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  rateText: {
    color: colors.text,
    ...textStyles.captionBold,
  },
  trackWrap: {
    height: spacing.md,
    justifyContent: 'center',
  },
  track: {
    borderRadius: radius.xs,
    height: spacing.xxs,
  },
  trackFill: {
    height: '100%',
  },
});
