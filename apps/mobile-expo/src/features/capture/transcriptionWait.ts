import type {
  BridgeSubscription,
  TranscriptionEventDTO,
} from "../../native/MemoraNative.types";

export type TranscriptionListener = (
  taskId: string,
  listener: (event: TranscriptionEventDTO) => void,
) => BridgeSubscription;

export type TranscriptionCompletionOutcome =
  | "completed"
  | "failed"
  | "cancelled"
  | "timeout";

/** 完了イベントを待つ上限。JS タイマーはアプリ停止中は進まないため、
 *  実質的な待機時間はアプリが起動している時間に限られる。 */
export const TRANSCRIPTION_COMPLETION_TIMEOUT_MS = 30 * 60 * 1000;

/**
 * startTranscription が返した task.id 宛のイベントを購読し、終端イベント
 * （completed / failed / cancelled）またはタイムアウトまで待つ。
 *
 * - どの経路でも必ず購読解除してから解決する（完了後のリスナー残留を防ぐ）。
 * - completed のみが「本文の保存が終わった」ことを表す。呼び出し側は
 *   completed 以外（failed / cancelled / timeout）で要約を開始してはならない。
 * - progress は逐次 onProgress へ渡すが、終端判定には使わない。
 */
export async function waitForTranscriptionCompletion(
  addListener: TranscriptionListener,
  taskId: string,
  options: {
    timeoutMs?: number;
    onProgress?: (progress: number) => void;
  } = {},
): Promise<TranscriptionCompletionOutcome> {
  const timeoutMs = options.timeoutMs ?? TRANSCRIPTION_COMPLETION_TIMEOUT_MS;
  return new Promise<TranscriptionCompletionOutcome>((resolve) => {
    let settled = false;
    let subscription: BridgeSubscription | undefined;
    let timeout: ReturnType<typeof setTimeout> | undefined;

    const finish = (outcome: TranscriptionCompletionOutcome) => {
      if (settled) return;
      settled = true;
      if (timeout !== undefined) clearTimeout(timeout);
      // 失敗・キャンセル・タイムアウトでも購読を確実に解除してから解決する。
      subscription?.remove();
      resolve(outcome);
    };

    try {
      subscription = addListener(taskId, (event) => {
        if (settled) return;
        switch (event.type) {
          case "completed":
            finish("completed");
            break;
          case "failed":
            finish("failed");
            break;
          case "cancelled":
            finish("cancelled");
            break;
          case "progress":
            options.onProgress?.(event.progress);
            break;
          default:
            // started など終端以外のイベントは無視する。
            break;
        }
      });
    } catch {
      // 購読自体を張れない場合は完了を待てないため failed 扱いにする。
      finish("failed");
      return;
    }

    if (timeoutMs > 0) {
      timeout = setTimeout(() => finish("timeout"), timeoutMs);
    }
  });
}
