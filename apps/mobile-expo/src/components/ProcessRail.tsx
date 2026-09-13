import { StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, textStyles } from '../design/tokens';

export type ProcessStepState = 'done' | 'active' | 'pending';

export type ProcessStep = {
  label: string;
  state: ProcessStepState;
};

/**
 * Open Design v2 の `.process-rail`。
 * 記録 → 文字起こし → 要約 の3段を横に並べ、完了は上罫、進行中は下2px罫と点で示す。
 * 状態を色では符号化しない（文言と罫線が正本）。
 */
export function ProcessRail({ steps, label }: { steps: ProcessStep[]; label: string }) {
  return (
    <View accessibilityLabel={label} accessibilityRole="progressbar" style={styles.rail}>
      {steps.map((step, index) => (
        <View
          key={step.label}
          style={[
            styles.step,
            index > 0 && styles.stepDivider,
            step.state === 'done' && styles.stepDone,
            step.state === 'active' && styles.stepActive,
          ]}
        >
          <View style={styles.stepLabelRow}>
            {step.state === 'active' ? <View style={styles.stepDot} /> : null}
            <Text style={[styles.stepLabel, step.state !== 'pending' && styles.stepLabelOn]}>
              {step.label}
            </Text>
          </View>
        </View>
      ))}
    </View>
  );
}

/** `.alert`: 左2px罫だけで注意を引く。地の色は変えない。 */
export function ProcessAlert({ title, body }: { title: string; body: string }) {
  return (
    <View style={styles.alert}>
      <Text style={styles.alertTitle}>{title}</Text>
      <Text style={styles.alertBody}>{body}</Text>
    </View>
  );
}

/** `.process-current`: 「現在の段階」と `n / 3`。 */
export function ProcessCurrent({ current, total }: { current: number; total: number }) {
  return (
    <View style={styles.current}>
      <Text style={styles.currentLabel}>現在の段階</Text>
      <Text style={styles.currentCount}>{`${current} / ${total}`}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  rail: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
  },
  step: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flex: 1,
    minWidth: 0,
    paddingVertical: spacing.sm,
  },
  stepDivider: {
    borderLeftColor: colors.border,
    borderLeftWidth: 1,
    paddingLeft: spacing.sm,
  },
  stepDone: {
    borderTopColor: colors.text,
    borderTopWidth: 2,
    marginTop: -2,
  },
  stepActive: {
    borderBottomColor: colors.text,
    borderBottomWidth: 2,
  },
  stepLabelRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  stepDot: {
    backgroundColor: colors.text,
    borderRadius: radius.circle,
    height: 6,
    width: 6,
  },
  stepLabel: { color: colors.textSecondary, flexShrink: 1, ...textStyles.label },
  stepLabelOn: { color: colors.text },

  alert: {
    borderLeftColor: colors.text,
    borderLeftWidth: 2,
    paddingLeft: spacing.sm,
  },
  alertTitle: { color: colors.text, ...textStyles.sectionTitle },
  alertBody: { color: colors.textSecondary, marginTop: spacing.xs, ...textStyles.body },

  current: {
    alignItems: 'baseline',
    flexDirection: 'row',
    gap: spacing.md,
    justifyContent: 'space-between',
    marginBottom: spacing.xs,
  },
  currentLabel: { color: colors.textSecondary, ...textStyles.label },
  currentCount: { color: colors.textSecondary, ...textStyles.monoBody },
});
