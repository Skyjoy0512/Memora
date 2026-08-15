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

    it('trims whitespace around the summary before building sections', () => {
      expect(
        buildExportMarkdown('  まとめ  \n', [{ time: '00:01', text: 'はじめに' }]),
      ).toBe('## 要約\n\nまとめ\n\n## 文字起こし\n\n00:01 はじめに');
    });

    it('omits the transcript section when segments produce no text', () => {
      expect(buildExportMarkdown('要約だけ', [{ time: ' ', text: ' ' }])).toBe(
        '## 要約\n\n要約だけ',
      );
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

    it('omits the summary section when the file has no summary', () => {
      const payload = buildExportPayload(
        { id: 'file-2', title: '打ち合わせ', summary: '', transcript: TRANSCRIPT },
        'file',
      );
      expect(payload.destination).toBe('file');
      expect(payload.text).not.toContain('## 要約');
      expect(payload.text).toContain('## 文字起こし');
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

    it('rejects a run too short to be a page id', () => {
      expect(extractNotionParentPageId('0'.repeat(31))).toBeNull();
    });

    it('rejects a 32-char run containing a non-hex character', () => {
      expect(extractNotionParentPageId('0123456789abcdef0123456789abcdeg')).toBeNull();
    });

    it('does not treat a dashed UUID form as a simple page id', () => {
      expect(extractNotionParentPageId('01234567-89ab-cdef-0123-456789abcdef')).toBeNull();
    });

    it('extracts the first 32-char hex run even when input is longer', () => {
      expect(extractNotionParentPageId('a'.repeat(33))).toBe('a'.repeat(32));
    });

    it('extracts a page id embedded in arbitrary surrounding text', () => {
      expect(extractNotionParentPageId(`prefix ${'b'.repeat(32)} suffix`)).toBe('b'.repeat(32));
      expect(extractNotionParentPageId(`  ${'c'.repeat(32)}  `)).toBe('c'.repeat(32));
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
