import { describe, expect, it } from 'vitest';
import {
  ASK_AI_MODEL_LABELS,
  ASK_AI_MODEL_OPTIONS,
  API_KEY_MISSING_MESSAGE,
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
    });

    it('falls back for generic and non-Error failures', () => {
      expect(mapAskAiError(new Error('network error')).kind).toBe('answer-failed');
      expect(mapAskAiError('boom').kind).toBe('answer-failed');
      expect(mapAskAiError(undefined).kind).toBe('answer-failed');
      expect(mapAskAiError(undefined).hint).toBeNull();
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
  });
});
