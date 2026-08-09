import { describe, expect, it } from 'vitest';
import { classifyTaskDue, taskDueDateForChoice } from '../taskDue';

const now = new Date('2026-08-09T10:00:00+09:00');

describe('classifyTaskDue', () => {
  it('classifies missing and invalid dates as 今後', () => {
    expect(classifyTaskDue(undefined, now)).toBe('今後');
    expect(classifyTaskDue(null, now)).toBe('今後');
    expect(classifyTaskDue('', now)).toBe('今後');
    expect(classifyTaskDue('not-a-date', now)).toBe('今後');
  });

  it('classifies today as 今日', () => {
    expect(classifyTaskDue('2026-08-09T05:00:00.000Z', now)).toBe('今日');
    expect(classifyTaskDue('2026-08-09T23:59:00+09:00', now)).toBe('今日');
  });

  it('classifies yesterday as 期限切れ', () => {
    expect(classifyTaskDue('2026-08-08T05:00:00.000Z', now)).toBe('期限切れ');
    expect(classifyTaskDue('2026-08-08T23:00:00+09:00', now)).toBe('期限切れ');
  });

  it('classifies tomorrow and later as 今後', () => {
    expect(classifyTaskDue('2026-08-10T05:00:00.000Z', now)).toBe('今後');
    expect(classifyTaskDue('2026-09-01T00:00:00.000Z', now)).toBe('今後');
  });
});

describe('taskDueDateForChoice', () => {
  it('returns today for 今日', () => {
    const value = taskDueDateForChoice('今日', now);
    expect(value).toBe('2026-08-09T01:00:00.000Z');
  });

  it('returns tomorrow for 明日', () => {
    const value = taskDueDateForChoice('明日', now);
    expect(value).toBe('2026-08-10T01:00:00.000Z');
  });

  it('returns undefined for 日付を選択', () => {
    expect(taskDueDateForChoice('日付を選択', now)).toBeUndefined();
  });
});
