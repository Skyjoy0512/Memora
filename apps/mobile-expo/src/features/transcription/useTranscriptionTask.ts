import { useCallback, useEffect, useRef, useState } from 'react';
import { MemoraNative } from '../../native/MemoraNative';
import type {
  BridgeSubscription,
  TranscriptionEventDTO,
  TranscriptionTaskDTO,
} from '../../native/MemoraNative.types';

export function useTranscriptionTask(audioFileId: string) {
  const [task, setTask] = useState<TranscriptionTaskDTO | null>(null);
  const [latestEvent, setLatestEvent] = useState<TranscriptionEventDTO | null>(null);
  const [error, setError] = useState<string | null>(null);
  const subscriptionRef = useRef<BridgeSubscription | null>(null);

  useEffect(() => {
    return () => {
      subscriptionRef.current?.remove();
    };
  }, []);

  const start = useCallback(async () => {
    setError(null);
    try {
      subscriptionRef.current?.remove();
      const nextTask = await MemoraNative.startTranscription(audioFileId);
      setTask(nextTask);
      setLatestEvent({
        audioFileId,
        message: '文字起こしを開始しました',
        progress: 0,
        taskId: nextTask.id,
        type: 'started',
      });
      subscriptionRef.current = MemoraNative.addTranscriptionListener(nextTask.id, (event) => {
        setLatestEvent(event);
        setTask((current) =>
          current
            ? {
                ...current,
                progress: event.progress,
                status:
                  event.type === 'completed'
                    ? 'completed'
                    : event.type === 'cancelled'
                      ? 'cancelled'
                      : event.type === 'failed'
                        ? 'failed'
                        : 'running',
              }
            : current,
        );
      });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : '文字起こしの開始に失敗しました');
    }
  }, [audioFileId]);

  const cancel = useCallback(async () => {
    if (!task) {
      return;
    }

    await MemoraNative.cancelTranscription(task.id);
    subscriptionRef.current?.remove();
  }, [task]);

  return {
    cancel,
    error,
    isRunning: task?.status === 'running',
    latestEvent,
    start,
    task,
  };
}
