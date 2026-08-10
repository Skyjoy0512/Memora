import { describe, expect, it } from 'vitest';
import { isCompleteCode, isEmailLike } from '../authFlow';

describe('authFlow (haribote)', () => {
  describe('isEmailLike', () => {
    it('accepts a value containing an @', () => {
      expect(isEmailLike('you@example.com')).toBe(true);
    });

    it('rejects values without an @', () => {
      expect(isEmailLike('')).toBe(false);
      expect(isEmailLike('nobody')).toBe(false);
    });
  });

  describe('isCompleteCode', () => {
    it('accepts exactly six digits', () => {
      expect(isCompleteCode('123456')).toBe(true);
    });

    it('rejects shorter or longer input', () => {
      expect(isCompleteCode('')).toBe(false);
      expect(isCompleteCode('12345')).toBe(false);
      expect(isCompleteCode('1234567')).toBe(false);
    });
  });
});
