import { useCallback, useEffect, useRef, useState } from 'react';
import { MemoraNative } from '../../native/MemoraNative';
import type {
  BridgeSubscription,
  TranscriptionEventDTO,
  TranscriptionTaskDTO,
} from '../../native/MemoraNative.types';

export function useTranscriptionTask(
  audioFileId: string,
  onCompleted?: (audioFileId: string) => Promise<void> | void,
) {
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
        if (event.type === 'completed') {
          void onCompleted?.(audioFileId);
        }
      });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : '文字起こしの開始に失敗しました');
    }
  }, [audioFileId, onCompleted]);

  const cancel = useCallback(async () => {
    if (!task) {
      return;
    }

    await MemoraNative.cancelTranscription(task.id);

    // native はキャンセル要求への応答のみを返し、cancelled 終端イベントは
    // 別途非同期で届く。応答前に終端イベント（completed/failed/cancelled）が
    // 届いていた場合はリスナー側で反映済みのため、ここでは残りのイベントを
    // 待たずに購読を解除し、応答時点の状態が非終端なら cancelled へ確定させる。
    // これにより終端イベントが応答の前後どちらに届いても running に残らない。
    const wasActive = task.status === 'queued' || task.status === 'running';
    subscriptionRef.current?.remove();
    subscriptionRef.current = null;
    setTask((current) =>
      current && (current.status === 'queued' || current.status === 'running')
        ? { ...current, status: 'cancelled' }
        : current,
    );
    if (wasActive) {
      setLatestEvent({
        audioFileId,
        message: '文字起こしをキャンセルしました',
        progress: 0,
        taskId: task.id,
        type: 'cancelled',
      });
    }
  }, [audioFileId, task]);

  return {
    cancel,
    error,
    isRunning: task?.status === 'running',
    latestEvent,
    start,
    task,
  };
}
