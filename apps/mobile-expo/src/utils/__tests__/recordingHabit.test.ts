import { describe, expect, it } from 'vitest';
import { buildRecordingHabit } from '../recordingHabit';

const now = new Date('2026-08-24T10:00:00+09:00');

describe('buildRecordingHabit', () => {
  it('returns an empty 28 day window when there is no record', () => {
    const habit = buildRecordingHabit([], now);
    expect(habit.days).toHaveLength(28);
    expect(habit.totalDays).toBe(28);
    expect(habit.recordedCount).toBe(0);
    expect(habit.days.some(Boolean)).toBe(false);
  });

  it('marks today as the last cell', () => {
    const habit = buildRecordingHabit(['2026-08-24T01:00:00+09:00'], now);
    expect(habit.days[27]).toBe(true);
    expect(habit.recordedCount).toBe(1);
  });

  it('marks the oldest day in range as the first cell', () => {
    // 28 日窓は 7/28 〜 8/24。
    const habit = buildRecordingHabit(['2026-07-28T23:59:00+09:00'], now);
    expect(habit.days[0]).toBe(true);
    expect(habit.recordedCount).toBe(1);
  });

  it('counts a day once even with several records on it', () => {
    const habit = buildRecordingHabit(
      ['2026-08-24T01:00:00+09:00', '2026-08-24T09:30:00+09:00', '2026-08-24T22:00:00+09:00'],
      now,
    );
    expect(habit.recordedCount).toBe(1);
  });

  it('ignores records outside the window and unparsable values', () => {
    const habit = buildRecordingHabit(
      ['2026-07-27T12:00:00+09:00', '2026-08-25T12:00:00+09:00', '', 'not-a-date'],
      now,
    );
    expect(habit.recordedCount).toBe(0);
  });

  it('honours a custom window length', () => {
    const habit = buildRecordingHabit(['2026-08-20T12:00:00+09:00'], now, 7);
    expect(habit.days).toHaveLength(7);
    expect(habit.totalDays).toBe(7);
    expect(habit.recordedCount).toBe(1);
  });

  it('returns an empty result for a non-positive window', () => {
    const habit = buildRecordingHabit(['2026-08-24T01:00:00+09:00'], now, 0);
    expect(habit.days).toHaveLength(0);
    expect(habit.recordedCount).toBe(0);
  });
});
