import { describe, expect, it } from 'vitest';
import {
  ASK_AI_MODEL_LABELS,
  ASK_AI_MODEL_OPTIONS,
  ASK_AI_HISTORY_MAX_MESSAGES,
  ASK_AI_HISTORY_MAX_CONTENT_LENGTH,
  API_KEY_MISSING_MESSAGE,
  buildAskAiHistory,
  buildAskAiRequest,
  buildFallbackKnowledgeResponse,
  describeNoTarget,
  isSupportedAskAiModel,
  mapAskAiError,
  resolveAskAiDataStatus,
  resolveAskAiScope,
} from '../askAiLogic';

describe('askAiLogic', () => {
  describe('resolveAskAiScope', () => {
    it('always allows global scope', () => {
      expect(resolveAskAiScope('global', {})).toEqual({ canSend: true, blocker: null });
      expect(resolveAskAiScope('global', { audioFileId: 'a' })).toEqual({
        canSend: true,
        blocker: null,
      });
    });

    it('blocks file scope without audioFileId', () => {
      expect(resolveAskAiScope('file', {})).toEqual({ canSend: false, blocker: 'no-target' });
      expect(resolveAskAiScope('file', { projectId: 'p' })).toEqual({
        canSend: false,
        blocker: 'no-target',
      });
      expect(resolveAskAiScope('file', { audioFileId: 'a' })).toEqual({
        canSend: true,
        blocker: null,
      });
    });

    it('blocks project scope without projectId', () => {
      expect(resolveAskAiScope('project', {})).toEqual({ canSend: false, blocker: 'no-target' });
      expect(resolveAskAiScope('project', { projectId: 'p' })).toEqual({
        canSend: true,
        blocker: null,
      });
    });

    it('treats empty-string ids as missing', () => {
      expect(resolveAskAiScope('file', { audioFileId: '' })).toEqual({
        canSend: false,
        blocker: 'no-target',
      });
      expect(resolveAskAiScope('project', { projectId: '' })).toEqual({
        canSend: false,
        blocker: 'no-target',
      });
    });

    it('ignores an audioFileId for project scope', () => {
      expect(resolveAskAiScope('project', { audioFileId: 'a' })).toEqual({
        canSend: false,
        blocker: 'no-target',
      });
    });
  });

  describe('buildAskAiRequest', () => {
    it('attaches audioFileId only for file scope', () => {
      expect(buildAskAiRequest('file', 'q', { audioFileId: 'a', projectId: 'p' })).toEqual({
        scope: 'file',
        question: 'q',
        audioFileId: 'a',
      });
    });

    it('attaches projectId only for project scope', () => {
      expect(buildAskAiRequest('project', 'q', { projectId: 'p', audioFileId: 'a' })).toEqual({
        scope: 'project',
        question: 'q',
        projectId: 'p',
      });
    });

    it('keeps global requests minimal', () => {
      expect(buildAskAiRequest('global', 'q', { audioFileId: 'a' })).toEqual({
        scope: 'global',
        question: 'q',
      });
    });

    it('leaves the target id absent when none is supplied', () => {
      const request = buildAskAiRequest('file', 'q', {});
      expect(request.scope).toBe('file');
      expect(request.audioFileId).toBeUndefined();
    });

    it('omits empty-string target ids', () => {
      expect(buildAskAiRequest('file', 'q', { audioFileId: '' })).toEqual({
        scope: 'file',
        question: 'q',
      });
      expect(buildAskAiRequest('project', 'q', { projectId: '' })).toEqual({
        scope: 'project',
        question: 'q',
      });
    });

    it('attaches sessionId and history for a follow-up question', () => {
      const request = buildAskAiRequest('global', 'q2', {}, {
        sessionId: 'session-1',
        history: [
          { role: 'user', content: 'q1' },
          { role: 'assistant', content: 'a1' },
        ],
      });
      expect(request).toEqual({
        scope: 'global',
        question: 'q2',
        sessionId: 'session-1',
        history: [
          { role: 'user', content: 'q1' },
          { role: 'assistant', content: 'a1' },
        ],
      });
    });

    it('attaches history only when it is non-empty', () => {
      const request = buildAskAiRequest('file', 'q2', { audioFileId: 'a' }, {
        sessionId: 'session-1',
        history: [],
      });
      expect(request).toEqual({
        scope: 'file',
        question: 'q2',
        audioFileId: 'a',
        sessionId: 'session-1',
      });
      expect(request.history).toBeUndefined();
    });

    it('omits an empty-string sessionId', () => {
      const request = buildAskAiRequest('global', 'q', {}, { sessionId: '' });
      expect(request.sessionId).toBeUndefined();
    });

    it('keeps the request minimal without a continuation', () => {
      const request = buildAskAiRequest('global', 'q', {});
      expect(request.sessionId).toBeUndefined();
      expect(request.history).toBeUndefined();
    });
  });

  describe('buildAskAiHistory', () => {
    it('maps recent user and assistant messages in order', () => {
      const history = buildAskAiHistory([
        { role: 'user', text: 'q1' },
        { role: 'assistant', text: 'a1' },
        { role: 'user', text: 'q2' },
      ]);
      expect(history).toEqual([
        { role: 'user', content: 'q1' },
        { role: 'assistant', content: 'a1' },
        { role: 'user', content: 'q2' },
      ]);
    });

    it('excludes sample and error-placeholder assistant messages but keeps questions', () => {
      const history = buildAskAiHistory([
        { role: 'user', text: 'q1' },
        { role: 'assistant', text: 'サンプル回答です', isSample: true },
        { role: 'user', text: 'q2' },
        { role: 'assistant', text: '取得に失敗しました', hint: 'api-key' },
      ]);
      expect(history).toEqual([
        { role: 'user', content: 'q1' },
        { role: 'user', content: 'q2' },
      ]);
    });

    it('keeps only the latest ASK_AI_HISTORY_MAX_MESSAGES messages', () => {
      const many = Array.from({ length: ASK_AI_HISTORY_MAX_MESSAGES + 4 }, (_, index) => ({
        id: `u${index}`,
        role: 'user' as const,
        text: `q${index}`,
      }));
      const history = buildAskAiHistory(many);
      expect(history).toHaveLength(ASK_AI_HISTORY_MAX_MESSAGES);
      expect(history[0].content).toBe(`q${many.length - ASK_AI_HISTORY_MAX_MESSAGES}`);
      expect(history[history.length - 1].content).toBe(`q${many.length - 1}`);
    });

    it('truncates a message longer than ASK_AI_HISTORY_MAX_CONTENT_LENGTH', () => {
      const long = 'あ'.repeat(ASK_AI_HISTORY_MAX_CONTENT_LENGTH + 10);
      const history = buildAskAiHistory([{ role: 'user', text: long }]);
      expect(history[0].content.length).toBe(ASK_AI_HISTORY_MAX_CONTENT_LENGTH + 1);
      expect(history[0].content.endsWith('…')).toBe(true);
    });

    it('returns an empty history for no messages', () => {
      expect(buildAskAiHistory([])).toEqual([]);
    });
  });

  describe('describeNoTarget', () => {
    it('explains file scope target selection', () => {
      const noTarget = describeNoTarget('file');
      expect(noTarget.title).toContain('ファイル');
      expect(noTarget.body.length).toBeGreaterThan(0);
    });

    it('explains project scope target selection', () => {
      const noTarget = describeNoTarget('project');
      expect(noTarget.title).toContain('プロジェクト');
      expect(noTarget.body.length).toBeGreaterThan(0);
    });
  });

  describe('resolveAskAiDataStatus', () => {
    it('maps unknown record state to loading', () => {
      expect(resolveAskAiDataStatus(null)).toBe('loading');
    });

    it('maps no records to empty', () => {
      expect(resolveAskAiDataStatus(false)).toBe('empty');
    });

    it('maps existing records to ready', () => {
      expect(resolveAskAiDataStatus(true)).toBe('ready');
    });
  });

  describe('mapAskAiError', () => {
    it('detects the native API-key error', () => {
      const mapping = mapAskAiError(new Error('選択したプロバイダーのAPIキーが設定されていません。'));
      expect(mapping.kind).toBe('api-key-missing');
      expect(mapping.hint).toBe('api-key');
      expect(mapping.message).toBe(API_KEY_MISSING_MESSAGE);
    });

    it('detects target lookup errors', () => {
      expect(mapAskAiError(new Error('質問対象が見つかりません。')).kind).toBe('target-unavailable');
      expect(mapAskAiError(new Error('質問対象を識別できません。')).hint).toBeNull();
      expect(mapAskAiError('対象が見つかりません').kind).toBe('target-unavailable');
    });

    it('detects api-key variants with and without a full-width space', () => {
      expect(mapAskAiError(new Error('API キーが設定されていません。')).kind).toBe('api-key-missing');
      expect(mapAskAiError(new Error('apiKey is required')).kind).toBe('api-key-missing');
      expect(mapAskAiError(new Error('APIキーが未設定です')).hint).toBe('api-key');
    });

    it('falls back for generic and non-Error failures', () => {
      expect(mapAskAiError(new Error('network error')).kind).toBe('answer-failed');
      expect(mapAskAiError('boom').kind).toBe('answer-failed');
      expect(mapAskAiError(undefined).kind).toBe('answer-failed');
      expect(mapAskAiError(undefined).hint).toBeNull();
    });

    it('maps non-Error thrown values to answer-failed', () => {
      expect(mapAskAiError(null).kind).toBe('answer-failed');
      expect(mapAskAiError({}).kind).toBe('answer-failed');
      expect(mapAskAiError(42).kind).toBe('answer-failed');
    });
  });

  describe('model selection', () => {
    it('exposes only Auto and OpenAI for the 1.0 native surface', () => {
      expect(ASK_AI_MODEL_OPTIONS).toEqual(['auto', 'OpenAI']);
      expect(ASK_AI_MODEL_OPTIONS.every(isSupportedAskAiModel)).toBe(true);
    });

    it('rejects unimplemented providers', () => {
      expect(isSupportedAskAiModel('Gemini')).toBe(false);
      expect(isSupportedAskAiModel('DeepSeek')).toBe(false);
      expect(isSupportedAskAiModel('Local')).toBe(false);
      expect(isSupportedAskAiModel('unknown')).toBe(false);
    });

    it('accepts the two wired models', () => {
      expect(isSupportedAskAiModel('auto')).toBe(true);
      expect(isSupportedAskAiModel('OpenAI')).toBe(true);
    });

    it('rejects unknown and non-model inputs', () => {
      expect(isSupportedAskAiModel(undefined)).toBe(false);
      expect(isSupportedAskAiModel(null)).toBe(false);
      expect(isSupportedAskAiModel('')).toBe(false);
      expect(isSupportedAskAiModel('auto ')).toBe(false);
      expect(isSupportedAskAiModel('openai')).toBe(false);
      expect(isSupportedAskAiModel(42)).toBe(false);
    });

    it('labels every option', () => {
      for (const model of ASK_AI_MODEL_OPTIONS) {
        expect(ASK_AI_MODEL_LABELS[model].length).toBeGreaterThan(0);
      }
    });
  });

  describe('buildFallbackKnowledgeResponse', () => {
    it('marks the fallback as a sample answer', () => {
      const response = buildFallbackKnowledgeResponse({ scope: 'global', question: 'q' });
      expect(response.isSample).toBe(true);
      expect(response.answer).toContain('サンプル回答');
      expect(response.sources.some((source) => source.includes('サンプル'))).toBe(true);
    });

    it('preserves the requested scope', () => {
      expect(buildFallbackKnowledgeResponse({ scope: 'file', question: 'q' }).scope).toBe('file');
      expect(buildFallbackKnowledgeResponse({ scope: 'project', question: 'q' }).scope).toBe(
        'project',
      );
    });

    it('preserves the request sessionId when provided', () => {
      const response = buildFallbackKnowledgeResponse({
        scope: 'global',
        question: 'q',
        sessionId: 's-1',
      });
      expect(response.sessionId).toBe('s-1');
    });

    it('generates a sample session and id for requests without one', () => {
      const response = buildFallbackKnowledgeResponse({ scope: 'global', question: 'q' });
      expect(response.sessionId).toMatch(/^sample-session-\d+$/);
      expect(response.id).toMatch(/^sample-query-global-\d+$/);
      expect(new Date(response.answeredAt).getTime()).not.toBeNaN();
    });
  });
});
