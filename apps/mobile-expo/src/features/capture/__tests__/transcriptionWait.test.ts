import { describe, expect, it, vi } from "vitest";
import type {
  BridgeSubscription,
  TranscriptionEventDTO,
} from "../../../native/MemoraNative.types";
import {
  waitForTranscriptionCompletion,
  type TranscriptionListener,
} from "../transcriptionWait";

function createFakeSubscription() {
  let handler: ((event: TranscriptionEventDTO) => void) | undefined;
  const remove = vi.fn(() => {
    handler = undefined;
  });
  const subscription: BridgeSubscription = { remove };
  const addListener = vi.fn<TranscriptionListener>((_taskId, listener) => {
    handler = listener;
    return subscription;
  });
  const emit = (event: TranscriptionEventDTO) => handler?.(event);
  return { addListener, emit, remove, subscription };
}

const baseEvent = {
  audioFileId: "audio-1",
  message: "",
  progress: 0,
  taskId: "task-1",
};

describe("waitForTranscriptionCompletion", () => {
  it("subscribes with the returned task id", async () => {
    const { addListener } = createFakeSubscription();
    const pending = waitForTranscriptionCompletion(addListener, "task-1", {
      timeoutMs: 0,
    });
    expect(addListener).toHaveBeenCalledWith(
      "task-1",
      expect.any(Function),
    );
    // 終端イベントなしでは解決しないこと（未解決のまま購読だけ張られる）。
    await expect(
      Promise.race([
        pending,
        Promise.resolve("still-pending").then(() => "still-pending"),
      ]),
    ).resolves.toBe("still-pending");
  });

  it("resolves completed and removes the subscription", async () => {
    const { addListener, emit, remove } = createFakeSubscription();
    const outcome = waitForTranscriptionCompletion(addListener, "task-1", {
      timeoutMs: 0,
    });
    emit({ ...baseEvent, type: "completed", progress: 1 });
    await expect(outcome).resolves.toBe("completed");
    expect(remove).toHaveBeenCalledTimes(1);
  });

  it("resolves failed and removes the subscription", async () => {
    const { addListener, emit, remove } = createFakeSubscription();
    const outcome = waitForTranscriptionCompletion(addListener, "task-1", {
      timeoutMs: 0,
    });
    emit({ ...baseEvent, type: "failed" });
    await expect(outcome).resolves.toBe("failed");
    expect(remove).toHaveBeenCalledTimes(1);
  });

  it("resolves cancelled and removes the subscription", async () => {
    const { addListener, emit, remove } = createFakeSubscription();
    const outcome = waitForTranscriptionCompletion(addListener, "task-1", {
      timeoutMs: 0,
    });
    emit({ ...baseEvent, type: "cancelled" });
    await expect(outcome).resolves.toBe("cancelled");
    expect(remove).toHaveBeenCalledTimes(1);
  });

  it("times out without a terminal event and removes the subscription", async () => {
    vi.useFakeTimers();
    try {
      const { addListener, remove } = createFakeSubscription();
      const outcome = waitForTranscriptionCompletion(addListener, "task-1", {
        timeoutMs: 5000,
      });
      vi.advanceTimersByTime(5000);
      await expect(outcome).resolves.toBe("timeout");
      expect(remove).toHaveBeenCalledTimes(1);
    } finally {
      vi.useRealTimers();
    }
  });

  it("ignores started events while waiting", async () => {
    const { addListener, emit, remove } = createFakeSubscription();
    const outcome = waitForTranscriptionCompletion(addListener, "task-1", {
      timeoutMs: 0,
    });
    emit({ ...baseEvent, type: "started" });
    emit({ ...baseEvent, type: "progress", progress: 0.4 });
    emit({ ...baseEvent, type: "completed", progress: 1 });
    await expect(outcome).resolves.toBe("completed");
    expect(remove).toHaveBeenCalledTimes(1);
  });

  it("reports progress events without settling until a terminal event", async () => {
    const { addListener, emit } = createFakeSubscription();
    const onProgress = vi.fn();
    const outcome = waitForTranscriptionCompletion(addListener, "task-1", {
      onProgress,
      timeoutMs: 0,
    });
    emit({ ...baseEvent, type: "progress", progress: 0.2 });
    emit({ ...baseEvent, type: "progress", progress: 0.8 });
    expect(onProgress).toHaveBeenNthCalledWith(1, 0.2);
    expect(onProgress).toHaveBeenNthCalledWith(2, 0.8);
    emit({ ...baseEvent, type: "completed", progress: 1 });
    await expect(outcome).resolves.toBe("completed");
  });

  it("ignores events after the first terminal event", async () => {
    const { addListener, emit, remove } = createFakeSubscription();
    const onProgress = vi.fn();
    const outcome = waitForTranscriptionCompletion(addListener, "task-1", {
      onProgress,
      timeoutMs: 0,
    });
    emit({ ...baseEvent, type: "completed", progress: 1 });
    emit({ ...baseEvent, type: "failed" });
    emit({ ...baseEvent, type: "progress", progress: 0.5 });
    await expect(outcome).resolves.toBe("completed");
    expect(onProgress).not.toHaveBeenCalled();
    expect(remove).toHaveBeenCalledTimes(1);
  });

  it("treats a throwing addListener as failed and still settles", async () => {
    const addListener = vi.fn<TranscriptionListener>(() => {
      throw new Error("listener unavailable");
    });
    await expect(
      waitForTranscriptionCompletion(addListener, "task-1", { timeoutMs: 0 }),
    ).resolves.toBe("failed");
  });
});
