import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, spacing, textStyles } from '../design/tokens';
import { NumericText } from './NumericText';
import { ProcessAlert, ProcessCurrent, ProcessRail, type ProcessStep } from './ProcessRail';
import type {
  TranscriptionEventDTO,
  TranscriptionTaskDTO,
} from '../native/MemoraNative.types';

type Props = {
  error: string | null;
  event: TranscriptionEventDTO | null;
  isRunning: boolean;
  onCancel: () => void;
  onStart: () => void;
  task: TranscriptionTaskDTO | null;
};

/**
 * Open Design v2 の `processing` / `processing-error` 画面を、記録詳細の
 * 文字起こしタブに埋め込んだもの。プロトタイプでは独立画面だが、RN では
 * 記録詳細が処理状況の置き場所なので、レール＋現在の段階だけを持ち込む。
 */
export function TranscriptionProgressCard({
  error,
  event,
  isRunning,
  onCancel,
  onStart,
  task,
}: Props) {
  const progress = Math.round((event?.progress ?? task?.progress ?? 0) * 100);
  const isCompleted = task?.status === 'completed';
  const hasFailed = Boolean(error) || task?.status === 'failed';

  const steps: ProcessStep[] = [
    { label: '記録済み', state: 'done' },
    {
      label: hasFailed ? '失敗' : isRunning ? '文字起こし中' : isCompleted ? '文字起こし済み' : '文字起こし待ち',
      state: hasFailed || isRunning || isCompleted ? 'active' : 'pending',
    },
    { label: '要約待ち', state: isCompleted ? 'active' : 'pending' },
  ];

  return (
    <View style={styles.block}>
      <ProcessRail
        label={hasFailed ? '処理に失敗' : '処理の進捗'}
        steps={steps}
      />

      {hasFailed ? (
        <View style={styles.section}>
          <ProcessAlert
            title="文字起こしを完了できませんでした"
            body="接続を確認して、もう一度試してください。音声はこのデバイスに残っています。"
          />
          {error ? <Text style={styles.detailText}>{error}</Text> : null}
        </View>
      ) : (
        <View style={styles.section}>
          <ProcessCurrent current={isCompleted ? 3 : isRunning ? 2 : 1} total={3} />
          <Text style={styles.title}>
            {isCompleted ? '文字起こしが終わりました' : isRunning ? '音声を文字にしています' : '文字起こしはまだ始まっていません'}
          </Text>
          <Text style={styles.body}>
            {event?.message ??
              (isRunning
                ? 'この画面を閉じても処理は続きます。音声はいつでも再生できます。'
                : '開始すると、音声を文字起こしして要約まで進みます。')}
          </Text>
          {isRunning ? (
            <View style={styles.progressRow}>
              <View style={styles.progressTrack}>
                <View style={[styles.progressFill, { width: `${progress}%` }]} />
              </View>
              <NumericText style={styles.progressText}>{`${progress}%`}</NumericText>
            </View>
          ) : null}
        </View>
      )}

      <View style={styles.actions}>
        <Pressable
          accessibilityLabel={hasFailed ? '再試行する' : isCompleted ? '再実行' : '文字起こしを開始'}
          accessibilityRole="button"
          accessibilityState={{ disabled: isRunning }}
          disabled={isRunning}
          onPress={onStart}
          style={({ pressed }) => [styles.primaryButton, isRunning && styles.disabled, pressed && styles.pressed]}
        >
          <Text style={styles.primaryText}>
            {hasFailed ? '再試行する' : isCompleted ? '再実行' : '開始'}
          </Text>
        </Pressable>
        {isRunning ? (
          <Pressable
            accessibilityLabel="文字起こしをキャンセル"
            accessibilityRole="button"
            onPress={onCancel}
            style={({ pressed }) => [styles.secondaryButton, pressed && styles.pressed]}
          >
            <Text style={styles.secondaryText}>キャンセル</Text>
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  block: { gap: spacing.xxl },
  section: { gap: spacing.xs },
  title: { color: colors.text, ...textStyles.sectionTitle },
  body: { color: colors.textSecondary, ...textStyles.body },
  detailText: { color: colors.textSecondary, marginTop: spacing.xs, ...textStyles.footnote },
  progressRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm, marginTop: spacing.xs },
  progressTrack: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 0,
    flex: 1,
    height: 3,
    overflow: 'hidden',
  },
  progressFill: { backgroundColor: colors.text, borderRadius: 0, height: '100%' },
  progressText: { color: colors.textSecondary, ...textStyles.monoBody },
  actions: { flexDirection: 'row', gap: spacing.sm },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderColor: colors.accent,
    borderRadius: 0,
    borderWidth: 1,
    flex: 1,
    justifyContent: 'center',
    minHeight: 44,
  },
  primaryText: { color: colors.textInverse, ...textStyles.footnoteBold },
  secondaryButton: {
    alignItems: 'center',
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    flex: 1,
    justifyContent: 'center',
    minHeight: 44,
  },
  secondaryText: { color: colors.text, ...textStyles.footnoteBold },
  disabled: { opacity: 0.38 },
  pressed: { opacity: 0.62 },
});
