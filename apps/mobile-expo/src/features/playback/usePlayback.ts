import { useCallback, useEffect, useRef, useState } from 'react';
import { MemoraNative } from '../../native/MemoraNative';
import type { PlaybackStatusDTO } from '../../native/MemoraNative.types';

const RATE_STEPS = [1, 1.25, 1.5, 2];

export function usePlayback(fileId: string | undefined) {
  const [status, setStatus] = useState<PlaybackStatusDTO | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const pollRef = useRef<ReturnType<typeof setInterval> | undefined>(undefined);

  useEffect(() => {
    if (!fileId) return;
    let isMounted = true;
    setIsLoading(true);
    setError(null);

    MemoraNative.loadPlayback(fileId)
      .then((nextStatus) => {
        if (!isMounted) return;
        setStatus(nextStatus);
        setIsLoading(false);
      })
      .catch((loadError: unknown) => {
        if (!isMounted) return;
        setError(loadError instanceof Error ? loadError.message : '再生を初期化できませんでした。');
        setIsLoading(false);
      });

    pollRef.current = setInterval(() => {
      void MemoraNative.getPlaybackStatus().then((nextStatus) => {
        if (isMounted && nextStatus) {
          setStatus(nextStatus);
        }
      });
    }, 300);

    return () => {
      isMounted = false;
      if (pollRef.current) clearInterval(pollRef.current);
    };
  }, [fileId]);

  const play = useCallback(async () => {
    try {
      setStatus(await MemoraNative.playPlayback());
    } catch (playError: unknown) {
      setError(playError instanceof Error ? playError.message : '再生を開始できませんでした。');
    }
  }, []);

  const pause = useCallback(async () => {
    try {
      setStatus(await MemoraNative.pausePlayback());
    } catch (pauseError: unknown) {
      setError(pauseError instanceof Error ? pauseError.message : '一時停止できませんでした。');
    }
  }, []);

  const seek = useCallback(async (position: number) => {
    try {
      setStatus(await MemoraNative.seekPlayback(position));
    } catch (seekError: unknown) {
      setError(seekError instanceof Error ? seekError.message : 'シークできませんでした。');
    }
  }, []);

  const cycleRate = useCallback(async () => {
    const currentIndex = RATE_STEPS.indexOf(status?.rate ?? 1);
    const nextRate = RATE_STEPS[(currentIndex + 1) % RATE_STEPS.length];
    try {
      setStatus(await MemoraNative.setPlaybackRate(nextRate));
    } catch (rateError: unknown) {
      setError(rateError instanceof Error ? rateError.message : '速度を変更できませんでした。');
    }
  }, [status?.rate]);

  return { cycleRate, error, isLoading, pause, play, seek, status };
}
