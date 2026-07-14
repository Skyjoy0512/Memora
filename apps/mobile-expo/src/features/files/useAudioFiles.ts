import { useCallback, useEffect, useState } from 'react';
import { MemoraNative } from '../../native/MemoraNative';
import type { AudioFile } from '../../types/memora';

type AsyncState<T> = {
  data: T;
  error: string | null;
  isLoading: boolean;
};

type AudioFileState = AsyncState<AudioFile | undefined> & {
  setAudioFile: (file: AudioFile) => void;
};

type AudioFilesState = AsyncState<AudioFile[]> & {
  refresh: (options?: { silent?: boolean }) => Promise<void>;
  upsertAudioFile: (file: AudioFile) => void;
  removeAudioFile: (id: string) => void;
};

export function useAudioFiles(): AudioFilesState {
  const [state, setState] = useState<AsyncState<AudioFile[]>>({
    data: [],
    error: null,
    isLoading: true,
  });

  const refresh = useCallback(async (options?: { silent?: boolean }) => {
    setState((current) => ({
      ...current,
      error: null,
      isLoading: options?.silent ? current.isLoading : true,
    }));

    try {
      const files = await MemoraNative.listAudioFiles();
      setState({ data: files, error: null, isLoading: false });
    } catch (error: unknown) {
      setState({
        data: [],
        error: error instanceof Error ? error.message : 'Unknown bridge error',
        isLoading: false,
      });
    }
  }, []);

  const upsertAudioFile = useCallback((file: AudioFile) => {
    setState((current) => ({
      ...current,
      data: [file, ...current.data.filter((existingFile) => existingFile.id !== file.id)],
      error: null,
      isLoading: false,
    }));
  }, []);

  const removeAudioFile = useCallback((id: string) => {
    setState((current) => ({
      ...current,
      data: current.data.filter((file) => file.id !== id),
      error: null,
      isLoading: false,
    }));
  }, []);

  useEffect(() => {
    let isMounted = true;

    MemoraNative.listAudioFiles()
      .then((files) => {
        if (isMounted) {
          setState({ data: files, error: null, isLoading: false });
        }
      })
      .catch((error: unknown) => {
        if (isMounted) {
          setState({
            data: [],
            error: error instanceof Error ? error.message : 'Unknown bridge error',
            isLoading: false,
          });
        }
      });

    return () => {
      isMounted = false;
    };
  }, []);

  return { ...state, refresh, removeAudioFile, upsertAudioFile };
}

export function useAudioFile(fileId?: string): AudioFileState {
  const [state, setState] = useState<AsyncState<AudioFile | undefined>>({
    data: undefined,
    error: null,
    isLoading: true,
  });

  useEffect(() => {
    let isMounted = true;

    if (!fileId) {
      setState({ data: undefined, error: 'Missing file id', isLoading: false });
      return () => {
        isMounted = false;
      };
    }

    MemoraNative.getAudioFile(fileId)
      .then((file) => {
        if (isMounted) {
          setState({ data: file, error: null, isLoading: false });
        }
      })
      .catch((error: unknown) => {
        if (isMounted) {
          setState({
            data: undefined,
            error: error instanceof Error ? error.message : 'Unknown bridge error',
            isLoading: false,
          });
        }
      });

    return () => {
      isMounted = false;
    };
  }, [fileId]);

  const setAudioFile = useCallback((file: AudioFile) => {
    setState({ data: file, error: null, isLoading: false });
  }, []);

  return { ...state, setAudioFile };
}
