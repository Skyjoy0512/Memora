import type { TranscriptSegment } from '../types/memora';
import type { TaskDTO } from './MemoraNative.types';

export const TASK_TITLE_MAX_LENGTH = 80;

/** タスクタイトルを安全な長さに整形する（改行/連続空白を1空白に潰し、超過は末尾に…）。 */
export function truncateTaskTitle(text: string, maxLength = TASK_TITLE_MAX_LENGTH): string {
  const normalized = text.replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, maxLength).trimEnd()}…`;
}

function newTaskId(): string {
  return `task-${Date.now()}`;
}

/** 文字起こしセグメントからタスクDTOを組み立てる（priority = medium / dueDate = null）。 */
export function buildTaskFromTranscriptSegment(
  segment: Pick<TranscriptSegment, 'text'>,
  options: { audioFileId: string; id?: string; createdAt?: string },
): TaskDTO {
  return {
    id: options.id ?? newTaskId(),
    title: truncateTaskTitle(segment.text),
    priority: 'medium',
    dueDate: null,
    projectId: null,
    sourceAudioFileId: options.audioFileId,
    isCompleted: false,
    createdAt: options.createdAt ?? new Date().toISOString(),
  };
}

/** Ask AI の回答からタスクDTOを組み立てる（priority = medium）。sourceAudioFileId はファイルスコープの時のみ設定。 */
export function buildTaskFromAssistantAnswer(
  answerText: string,
  options: { sourceAudioFileId?: string | null; id?: string; createdAt?: string },
): TaskDTO {
  return {
    id: options.id ?? newTaskId(),
    title: truncateTaskTitle(answerText),
    priority: 'medium',
    dueDate: null,
    projectId: null,
    sourceAudioFileId: options.sourceAudioFileId ?? null,
    isCompleted: false,
    createdAt: options.createdAt ?? new Date().toISOString(),
  };
}
