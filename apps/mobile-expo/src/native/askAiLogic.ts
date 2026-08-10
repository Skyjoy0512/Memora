import type {
  KnowledgeQueryRequestDTO,
  KnowledgeQueryResponseDTO,
  KnowledgeQueryScope,
} from './MemoraNative.types';

// ── Model selection ─────────────────────────────────────
// Native (MemoraSharedStoreKnowledgeQuery) currently serves OpenAI only.
// The request DTO has no provider field; both options route to the native default.
export type AskAiModel = 'auto' | 'OpenAI';

export const ASK_AI_MODEL_OPTIONS: readonly AskAiModel[] = ['auto', 'OpenAI'];

export const ASK_AI_MODEL_LABELS: Record<AskAiModel, string> = {
  auto: '自動（現在は OpenAI）',
  OpenAI: 'OpenAI',
};

export function isSupportedAskAiModel(value: unknown): value is AskAiModel {
  return ASK_AI_MODEL_OPTIONS.includes(value as AskAiModel);
}

// ── Scope resolution ────────────────────────────────────
export type AskAiTargetIds = {
  audioFileId?: string;
  projectId?: string;
};

export type AskAiScopeBlocker = 'no-target';

export type AskAiScopeResolution = {
  canSend: boolean;
  blocker: AskAiScopeBlocker | null;
};

export function resolveAskAiScope(
  scope: KnowledgeQueryScope,
  targetIds: AskAiTargetIds,
): AskAiScopeResolution {
  if (scope === 'global') {
    return { canSend: true, blocker: null };
  }
  if (scope === 'file' && !targetIds.audioFileId) {
    return { canSend: false, blocker: 'no-target' };
  }
  if (scope === 'project' && !targetIds.projectId) {
    return { canSend: false, blocker: 'no-target' };
  }
  return { canSend: true, blocker: null };
}

export function buildAskAiRequest(
  scope: KnowledgeQueryScope,
  question: string,
  targetIds: AskAiTargetIds,
): KnowledgeQueryRequestDTO {
  if (scope === 'file') {
    return { scope, question, audioFileId: targetIds.audioFileId };
  }
  if (scope === 'project') {
    return { scope, question, projectId: targetIds.projectId };
  }
  return { scope, question };
}

export function describeNoTarget(scope: KnowledgeQueryScope): { title: string; body: string } {
  if (scope === 'file') {
    return {
      title: '質問するファイルが未選択です',
      body:
        'このスコープでは対象の記録を選ぶ必要があります。ファイル詳細画面から Ask AI を開くと対象が自動で設定される予定です。',
    };
  }
  return {
    title: '質問するプロジェクトが未選択です',
    body:
      'このスコープでは対象のプロジェクトを選ぶ必要があります。プロジェクト選択の実装後に利用可能になります。',
  };
}

// ── Data status ─────────────────────────────────────────
export type AskAiDataStatus = 'loading' | 'empty' | 'ready';

export function resolveAskAiDataStatus(hasRecords: boolean | null): AskAiDataStatus {
  if (hasRecords === null) {
    return 'loading';
  }
  return hasRecords ? 'ready' : 'empty';
}

// ── Error mapping ───────────────────────────────────────
export type AskAiErrorKind = 'api-key-missing' | 'target-unavailable' | 'answer-failed';

export type AskAiErrorMapping = {
  kind: AskAiErrorKind;
  message: string;
  hint: 'api-key' | null;
};

export const API_KEY_MISSING_MESSAGE =
  'OpenAI の API キーが設定されていません。設定画面から OpenAI の API キーを入力してください。';

export function mapAskAiError(error: unknown): AskAiErrorMapping {
  const raw = error instanceof Error ? error.message : String(error ?? '');
  if (raw.includes('APIキー') || raw.includes('API キー') || raw.includes('apiKey')) {
    return {
      kind: 'api-key-missing',
      message: API_KEY_MISSING_MESSAGE,
      hint: 'api-key',
    };
  }
  if (raw.includes('質問対象') || raw.includes('識別') || raw.includes('対象が見つかりません')) {
    return {
      kind: 'target-unavailable',
      message: '質問対象が見つかりません。全体スコープで試すか、対象を選び直してください。',
      hint: null,
    };
  }
  return {
    kind: 'answer-failed',
    message: '回答の取得に失敗しました。時間をおいて、もう一度お試しください。',
    hint: null,
  };
}

// ── Sample fallback (web / native-unavailable) ──────────
const SAMPLE_SOURCE_LABEL = 'サンプル回答（ネイティブ未接続）';

const FALLBACK_ANSWERS: Record<KnowledgeQueryScope, { answer: string; sources: string[] }> = {
  file: {
    answer:
      '（サンプル回答）このスコープの回答例です。ネイティブ接続時に、選択した記録の内容から回答します。',
    sources: ['Growth 定例'],
  },
  project: {
    answer:
      '（サンプル回答）このスコープの回答例です。ネイティブ接続時に、選択したプロジェクトの記録から回答します。',
    sources: ['React Native / Expo Migration Plan'],
  },
  global: {
    answer:
      '（サンプル回答）このスコープの回答例です。ネイティブ接続時に、すべての記録から実データで回答します。',
    sources: [],
  },
};

export function buildFallbackKnowledgeResponse(
  request: KnowledgeQueryRequestDTO,
): KnowledgeQueryResponseDTO {
  const scoped = FALLBACK_ANSWERS[request.scope] ?? FALLBACK_ANSWERS.global;
  return {
    answer: scoped.answer,
    answeredAt: new Date().toISOString(),
    id: `sample-query-${request.scope}-${Date.now()}`,
    isSample: true,
    scope: request.scope,
    sessionId: request.sessionId ?? `sample-session-${Date.now()}`,
    sources: [...scoped.sources, SAMPLE_SOURCE_LABEL],
  };
}
