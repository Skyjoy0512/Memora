import { describe, expect, it } from 'vitest';
import {
  buildExportMarkdown,
  buildExportPayload,
  extractNotionParentPageId,
  NOTION_SETUP_LABELS,
  resolveNotionSetupState,
} from '../exportLogic';

const TRANSCRIPT = [
  { id: '1', speaker: 'A', time: '00:00', text: 'こんにちは', confidence: 1 },
  { id: '2', speaker: 'B', time: '00:02', text: 'よろしくお願いします', confidence: 1 },
];

describe('exportLogic', () => {
  describe('buildExportMarkdown', () => {
    it('combines summary and transcript with section headings', () => {
      expect(buildExportMarkdown('まとめ本文', TRANSCRIPT)).toBe(
        '## 要約\n\nまとめ本文\n\n## 文字起こし\n\n00:00 こんにちは\n00:02 よろしくお願いします',
      );
    });

    it('omits empty summary section', () => {
      expect(buildExportMarkdown('', TRANSCRIPT)).toBe(
        '## 文字起こし\n\n00:00 こんにちは\n00:02 よろしくお願いします',
      );
    });

    it('omits empty transcript section', () => {
      expect(buildExportMarkdown('まとめ本文', [])).toBe('## 要約\n\nまとめ本文');
    });

    it('returns empty string when both sections are empty', () => {
      expect(buildExportMarkdown('', [])).toBe('');
    });
  });

  describe('buildExportPayload', () => {
    it('builds a payload for the file data', () => {
      const file = {
        id: 'file-1',
        title: 'Growth 定例',
        summary: '決定事項',
        transcript: TRANSCRIPT,
      };
      const payload = buildExportPayload(file, 'notion');
      expect(payload.title).toBe('Growth 定例');
      expect(payload.sourceFileId).toBe('file-1');
      expect(payload.destination).toBe('notion');
      expect(payload.text).toContain('## 要約');
      expect(payload.text).toContain('00:00 こんにちは');
      expect(payload.createdAt).toBeDefined();
    });
  });

  describe('extractNotionParentPageId', () => {
    it('extracts the 32-char hex page id from a page URL', () => {
      expect(
        extractNotionParentPageId(
          'https://www.notion.so/My-Page-0123456789abcdef0123456789abcdef?pvs=4',
        ),
      ).toBe('0123456789abcdef0123456789abcdef');
    });

    it('treats a bare page id as-is', () => {
      expect(extractNotionParentPageId('0123456789abcdef0123456789abcdef')).toBe(
        '0123456789abcdef0123456789abcdef',
      );
    });

    it('normalizes uppercase hex to lowercase', () => {
      expect(extractNotionParentPageId('0123456789ABCDEF0123456789ABCDEF')).toBe(
        '0123456789abcdef0123456789abcdef',
      );
    });

    it('returns null when no page id can be identified', () => {
      expect(extractNotionParentPageId('')).toBeNull();
      expect(extractNotionParentPageId('https://www.notion.so/My-Page')).toBeNull();
      expect(extractNotionParentPageId('short-id')).toBeNull();
    });
  });

  describe('resolveNotionSetupState', () => {
    it('is ready when token and parent page are configured', () => {
      expect(resolveNotionSetupState(true, true)).toBe('ready');
    });

    it('is not-configured when the token is missing', () => {
      expect(resolveNotionSetupState(false, true)).toBe('not-configured');
      expect(resolveNotionSetupState(false, false)).toBe('not-configured');
    });

    it('is parent-missing when only the token is configured', () => {
      expect(resolveNotionSetupState(true, false)).toBe('parent-missing');
    });

    it('labels every state', () => {
      const states = ['ready', 'token-missing', 'parent-missing', 'not-configured'] as const;
      for (const state of states) {
        expect(NOTION_SETUP_LABELS[state].length).toBeGreaterThan(0);
      }
    });
  });
});
