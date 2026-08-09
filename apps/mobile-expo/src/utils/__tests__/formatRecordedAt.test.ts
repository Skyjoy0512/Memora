import { describe, expect, it } from 'vitest';
import { formatRecordedAt } from '../formatRecordedAt';

const now = new Date('2026-07-20T12:00:00+09:00');

describe('formatRecordedAt', () => {
  it('formats ISO strings into Japanese relative labels', () => {
    expect(formatRecordedAt('2026-07-20T09:30:00+09:00', now)).toBe('今日 09:30');
    expect(formatRecordedAt('2026-07-19T10:02:00+09:00', now)).toBe('昨日 10:02');
    expect(formatRecordedAt('2026-07-08T11:30:00+09:00', now)).toBe('7月8日 11:30');
    expect(formatRecordedAt('2025-12-31T23:59:59+09:00', now)).toBe('2025年12月31日 23:59');
  });

  it('formats real-data ISO8601 (UTC Z) into local Japanese labels', () => {
    expect(formatRecordedAt('2026-07-18T12:33:42Z', now)).toBe('7月18日 21:33');
    expect(formatRecordedAt('2026-07-18T12:33:42.000+09:00', now)).toBe('7月18日 12:33');
  });

  it('returns invalid values unchanged instead of raw ISO leaks', () => {
    expect(formatRecordedAt('ただいま', now)).toBe('ただいま');
    expect(formatRecordedAt('native', now)).toBe('native');
    expect(formatRecordedAt('', now)).toBe('');
    expect(formatRecordedAt('not-a-date', now)).toBe('not-a-date');
  });

  it('returns already-formatted strings unchanged', () => {
    expect(formatRecordedAt('今日 10:02', now)).toBe('今日 10:02');
    expect(formatRecordedAt('7月8日 11:30', now)).toBe('7月8日 11:30');
  });
});
