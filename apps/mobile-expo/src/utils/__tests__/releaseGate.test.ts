import { describe, expect, it } from 'vitest';
import { isDevOnlyRoute, shouldExposeRoute } from '../releaseGate';

describe('releaseGate', () => {
  it('marks preview and dev-fonts as dev-only routes', () => {
    expect(isDevOnlyRoute('preview')).toBe(true);
    expect(isDevOnlyRoute('dev-fonts')).toBe(true);
  });

  it('keeps dev-only routes unavailable in release builds', () => {
    expect(shouldExposeRoute('preview', false)).toBe(false);
    expect(shouldExposeRoute('dev-fonts', false)).toBe(false);
  });

  it('keeps dev-only routes available in development builds', () => {
    expect(shouldExposeRoute('preview', true)).toBe(true);
    expect(shouldExposeRoute('dev-fonts', true)).toBe(true);
  });

  it('never gates production-facing routes such as auth and tabs', () => {
    expect(isDevOnlyRoute('auth')).toBe(false);
    expect(isDevOnlyRoute('(tabs)')).toBe(false);
    expect(isDevOnlyRoute('file/[id]')).toBe(false);
    expect(shouldExposeRoute('auth', false)).toBe(true);
    expect(shouldExposeRoute('(tabs)', false)).toBe(true);
    expect(shouldExposeRoute('file/[id]', false)).toBe(true);
  });
});
