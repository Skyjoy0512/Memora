import { describe, expect, it } from 'vitest';
import { formatStatus } from '../formatStatus';

describe('formatStatus', () => {
  it('maps real-data English statuses to Japanese labels', () => {
    expect(formatStatus('ready')).toBe('文字起こし済み');
    expect(formatStatus('processing')).toBe('文字起こし中');
    expect(formatStatus('failed')).toBe('確認が必要');
    expect(formatStatus('completed')).toBe('文字起こし済み');
    expect(formatStatus('unknown')).toBe('処理待ち');
  });

  it('maps existing RN audio statuses', () => {
    expect(formatStatus('queued')).toBe('文字起こし待ち');
    expect(formatStatus('transcribing')).toBe('文字起こし中');
    expect(formatStatus('summarized')).toBe('要約済み');
  });

  it('normalizes case and whitespace so English labels never leak', () => {
    expect(formatStatus('Ready')).toBe('文字起こし済み');
    expect(formatStatus(' PROCESSING ')).toBe('文字起こし中');
    expect(formatStatus('FAILED')).toBe('確認が必要');
  });

  it('falls back for empty, nullish, or unknown values', () => {
    expect(formatStatus('')).toBe('処理待ち');
    expect(formatStatus(undefined)).toBe('処理待ち');
    expect(formatStatus(null)).toBe('処理待ち');
    expect(formatStatus('some-unknown-state')).toBe('処理待ち');
  });
});
