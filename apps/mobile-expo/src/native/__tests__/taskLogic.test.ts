import { describe, expect, it } from 'vitest';
import {
  buildTaskFromAssistantAnswer,
  buildTaskFromTranscriptSegment,
  TASK_TITLE_MAX_LENGTH,
  truncateTaskTitle,
} from '../taskLogic';

describe('taskLogic', () => {
  describe('truncateTaskTitle', () => {
    it('keeps short text as-is', () => {
      expect(truncateTaskTitle('タスクを確認する')).toBe('タスクを確認する');
    });

    it('collapses newlines and repeated spaces into a single space', () => {
      expect(truncateTaskTitle(' 会議メモを\n整理\tする  ')).toBe('会議メモを 整理 する');
    });

    it('truncates long text with an ellipsis', () => {
      const long = 'あ'.repeat(TASK_TITLE_MAX_LENGTH + 20);
      const truncated = truncateTaskTitle(long);
      expect(truncated.length).toBe(TASK_TITLE_MAX_LENGTH + 1);
      expect(truncated.endsWith('…')).toBe(true);
    });

    it('honors a custom max length', () => {
      expect(truncateTaskTitle('あいうえお', 3)).toBe('あいう…');
    });
  });

  describe('buildTaskFromTranscriptSegment', () => {
    it('builds a medium-priority task linked to the source file', () => {
      const task = buildTaskFromTranscriptSegment(
        { text: 'この発言をタスク化する' },
        { audioFileId: 'file-1', id: 'task-1', createdAt: '2026-08-10T00:00:00Z' },
      );
      expect(task).toMatchObject({
        id: 'task-1',
        title: 'この発言をタスク化する',
        priority: 'medium',
        dueDate: null,
        projectId: null,
        sourceAudioFileId: 'file-1',
        isCompleted: false,
        createdAt: '2026-08-10T00:00:00Z',
      });
    });

    it('truncates the segment text for the title', () => {
      const long = '長'.repeat(120);
      const task = buildTaskFromTranscriptSegment({ text: long }, { audioFileId: 'file-1' });
      expect(task.title.endsWith('…')).toBe(true);
    });

    it('generates an id and createdAt when not provided', () => {
      const task = buildTaskFromTranscriptSegment({ text: 'タスク' }, { audioFileId: 'file-1' });
      expect(task.id).toMatch(/^task-\d+$/);
      expect(new Date(task.createdAt).getTime()).not.toBeNaN();
    });
  });

  describe('buildTaskFromAssistantAnswer', () => {
    it('builds a medium-priority task without a source link by default', () => {
      const task = buildTaskFromAssistantAnswer('回答をタスク化する', {
        id: 'task-2',
        createdAt: '2026-08-10T00:00:00Z',
      });
      expect(task).toMatchObject({
        id: 'task-2',
        title: '回答をタスク化する',
        priority: 'medium',
        dueDate: null,
        projectId: null,
        sourceAudioFileId: null,
        isCompleted: false,
        createdAt: '2026-08-10T00:00:00Z',
      });
    });

    it('links to the source audio file when a file-scoped id is present', () => {
      const task = buildTaskFromAssistantAnswer('ファイル回答をタスク化する', {
        sourceAudioFileId: 'file-2',
      });
      expect(task.sourceAudioFileId).toBe('file-2');
    });

    it('truncates the answer text for the title', () => {
      const long = '回答'.repeat(60);
      const task = buildTaskFromAssistantAnswer(long, {});
      expect(task.title.length).toBeLessThanOrEqual(TASK_TITLE_MAX_LENGTH + 1);
      expect(task.title.endsWith('…')).toBe(true);
    });
  });
});
