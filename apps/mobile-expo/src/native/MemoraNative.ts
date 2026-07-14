import { Platform } from 'react-native';

import { audioFiles } from '../mocks/memoraData';
import type { AudioFile } from '../types/memora';
import type {
  BridgeSubscription,
  BridgeInfoDTO,
  KnowledgeQueryRequestDTO,
  KnowledgeQueryResponseDTO,
  MemoraNativeModule,
  PhotoAttachmentDTO,
  PlaybackStatusDTO,
  ProcessingRetryDTO,
  ProcessingRetryRequestDTO,
  SettingsDTO,
  SummaryDTO,
  SummaryOptionsDTO,
  SummaryRequestDTO,
  TranscriptionEventDTO,
  TranscriptionTaskDTO,
} from './MemoraNative.types';

type NativeExpoModule = {
  listAudioFiles?: () => Promise<AudioFile[]>;
  getAudioFile?: (id: string) => Promise<AudioFile | null>;
  renameAudioFile?: (id: string, title: string) => Promise<AudioFile | null>;
  moveAudioFile?: (id: string, projectId: string | null) => Promise<AudioFile | null>;
  deleteAudioFile?: (id: string) => Promise<boolean>;
  getBridgeInfo?: () => Promise<BridgeInfoDTO>;
  loadSettings?: () => Promise<SettingsDTO>;
  saveSettings?: (settings: SettingsDTO) => Promise<void>;
  startRecording?: () => Promise<{ id: string; startedAt: string; source: 'iPhone' }>;
  pauseRecording?: (sessionId: string) => Promise<void>;
  resumeRecording?: (sessionId: string) => Promise<void>;
  discardRecording?: (sessionId: string) => Promise<void>;
  stopRecording?: (sessionId: string) => Promise<AudioFile>;
  importAudio?: (uri: string) => Promise<AudioFile>;
  startTranscription?: (audioFileId: string) => Promise<TranscriptionTaskDTO>;
  cancelTranscription?: (taskId: string) => Promise<void>;
  queryKnowledge?: (request: KnowledgeQueryRequestDTO) => Promise<KnowledgeQueryResponseDTO>;
  generateSummary?: (request: SummaryRequestDTO) => Promise<SummaryDTO>;
  loadPlayback?: (audioFileId: string) => Promise<PlaybackStatusDTO>;
  playPlayback?: () => Promise<PlaybackStatusDTO>;
  pausePlayback?: () => Promise<PlaybackStatusDTO>;
  seekPlayback?: (position: number) => Promise<PlaybackStatusDTO>;
  setPlaybackRate?: (rate: number) => Promise<PlaybackStatusDTO>;
  getPlaybackStatus?: () => Promise<PlaybackStatusDTO>;
  getMemoDraft?: (audioFileId: string) => Promise<string>;
  saveMemoDraft?: (audioFileId: string, text: string) => Promise<void>;
  listPhotoAttachments?: (audioFileId: string) => Promise<PhotoAttachmentDTO[]>;
  addPhotoAttachment?: (audioFileId: string, sourceUri: string) => Promise<PhotoAttachmentDTO>;
  deletePhotoAttachment?: (audioFileId: string, attachmentId: string) => Promise<boolean>;
  enqueueProcessingRetry?: (request: ProcessingRetryRequestDTO) => Promise<ProcessingRetryDTO>;
  listProcessingRetries?: () => Promise<ProcessingRetryDTO[]>;
  recordProcessingRetryFailure?: (
    id: string,
    lastError: string,
  ) => Promise<ProcessingRetryDTO | null>;
  completeProcessingRetry?: (id: string) => Promise<boolean>;
  addListener?: (
    eventName: 'onTranscriptionEvent',
    listener: (event: TranscriptionEventDTO) => void,
  ) => BridgeSubscription;
};

const listeners = new Map<string, Set<(event: TranscriptionEventDTO) => void>>();
const timers = new Map<string, ReturnType<typeof setInterval>>();
let fallbackGeneratedFiles: AudioFile[] = [];
let fallbackProcessingRetries: ProcessingRetryDTO[] = [];

const fallbackMemoNotes = new Map<string, { text: string; photos: PhotoAttachmentDTO[] }>();
let fallbackPlayback: PlaybackStatusDTO | undefined;
let fallbackPlaybackTimer: ReturnType<typeof setInterval> | undefined;

function fallbackMemoRecord(audioFileId: string) {
  const existing = fallbackMemoNotes.get(audioFileId);
  if (existing) return existing;
  const created = { text: '', photos: [] as PhotoAttachmentDTO[] };
  fallbackMemoNotes.set(audioFileId, created);
  return created;
}

function stopFallbackPlaybackTimer() {
  if (fallbackPlaybackTimer) {
    clearInterval(fallbackPlaybackTimer);
    fallbackPlaybackTimer = undefined;
  }
}

let settings: SettingsDTO = {
  transcriptionMode: 'local',
  summaryProvider: 'Gemini',
  speechAnalyzerEnabled: false,
};

const webSettingsKey = 'memora.reactNative.settings';

function loadFallbackSettings(): SettingsDTO {
  if (Platform.OS !== 'web') {
    return settings;
  }

  try {
    const rawSettings = globalThis.localStorage?.getItem(webSettingsKey);
    if (!rawSettings) {
      return settings;
    }

    const parsedSettings = JSON.parse(rawSettings) as Partial<SettingsDTO>;
    settings = {
      speechAnalyzerEnabled: parsedSettings.speechAnalyzerEnabled ?? false,
      summaryProvider: parsedSettings.summaryProvider ?? 'Gemini',
      transcriptionMode: parsedSettings.transcriptionMode ?? 'local',
    };
  } catch {
    return settings;
  }

  return settings;
}

function saveFallbackSettings(nextSettings: SettingsDTO) {
  settings = nextSettings;

  if (Platform.OS !== 'web') {
    return;
  }

  try {
    globalThis.localStorage?.setItem(webSettingsKey, JSON.stringify(nextSettings));
  } catch {
    // Keep the in-memory fallback even if browser storage is unavailable.
  }
}

function emit(event: TranscriptionEventDTO) {
  listeners.get(event.taskId)?.forEach((listener) => listener(event));
}

function addListener(
  taskId: string,
  listener: (event: TranscriptionEventDTO) => void,
): BridgeSubscription {
  const taskListeners = listeners.get(taskId) ?? new Set();
  taskListeners.add(listener);
  listeners.set(taskId, taskListeners);

  return {
    remove() {
      taskListeners.delete(listener);
      if (taskListeners.size === 0) {
        listeners.delete(taskId);
      }
    },
  };
}

function createGeneratedFile(sourceUri: string): AudioFile {
  return {
    id: `import-${Date.now()}`,
    title: sourceUri.split('/').pop() ?? 'Imported audio',
    project: 'Inbox',
    source: 'iPhone',
    recordedAt: 'ただいま',
    duration: '00:00',
    status: 'ready',
    summary: 'Native bridge 接続後に実ファイルのメタデータを表示します。',
    transcript: [],
    memo: [],
  };
}

function createFallbackKnowledgeResponse(
  request: KnowledgeQueryRequestDTO,
): KnowledgeQueryResponseDTO {
  const scopedAnswers: Record<KnowledgeQueryRequestDTO['scope'], { answer: string; sources: string[] }> =
    {
      file: {
        answer:
          'このファイルでは、Expo mock UI を先に固めてから native bridge を薄く足す方針が一番安全です。録音、取り込み、STT は既存Swift側を維持し、RNはDTOと状態表示から接続します。',
        sources: ['Growth 定例', 'File Detail memo'],
      },
      project: {
        answer:
          'プロジェクト全体では、Home、File Detail、Settings、Ask AI の確認ループが先行しています。次はSwiftDataの共有方式を決め、reader/mutatorをbootstrapから差し替える段階です。',
        sources: ['React Native / Expo Migration Plan', 'Bridge Contract'],
      },
      global: {
        answer:
          '全体横断では、STT保護境界、既存バックエンド維持、Expo Dev Clientでの実機確認が重要です。CoreSimulatorの書き込み問題が解けると、録音/取り込みのライブ確認に進めます。',
        sources: ['Migration handoff', 'Settings bridge diagnostics'],
      },
    };
  const scopedAnswer = scopedAnswers[request.scope];

  return {
    answer: scopedAnswer.answer,
    answeredAt: new Date().toISOString(),
    id: `mock-query-${request.scope}-${Date.now()}`,
    scope: request.scope,
    sources: scopedAnswer.sources,
  };
}

function upsertFallbackGeneratedFile(file: AudioFile) {
  fallbackGeneratedFiles = [
    file,
    ...fallbackGeneratedFiles.filter((existingFile) => existingFile.id !== file.id),
  ];
}

function loadNativeModule(): NativeExpoModule | undefined {
  if (Platform.OS === 'web') {
    return undefined;
  }

  try {
    const nativeModule = require('../../modules/memora-native').default as NativeExpoModule;
    return nativeModule;
  } catch {
    return undefined;
  }
}

async function withNative<T>(
  call: (nativeModule: NativeExpoModule) => Promise<T | null | undefined> | undefined,
): Promise<T | undefined> {
  const nativeModule = loadNativeModule();

  if (!nativeModule) {
    return undefined;
  }

  try {
    const result = await call(nativeModule);
    return result ?? undefined;
  } catch {
    return undefined;
  }
}

export const MemoraNative: MemoraNativeModule = {
  async listAudioFiles() {
    const nativeFiles = await withNative<AudioFile[]>((nativeModule) =>
      nativeModule.listAudioFiles?.(),
    );

    if (nativeFiles?.length) {
      return nativeFiles;
    }

    return [...fallbackGeneratedFiles, ...audioFiles];
  },
  async getAudioFile(id: string) {
    const nativeFile = await withNative<AudioFile>((nativeModule) =>
      nativeModule.getAudioFile?.(id),
    );

    if (nativeFile) {
      return nativeFile;
    }

    const fallbackGeneratedFile = fallbackGeneratedFiles.find((file) => file.id === id);
    if (fallbackGeneratedFile) {
      return fallbackGeneratedFile;
    }

    if (id === 'empty-transcript') {
      return {
        ...audioFiles[0],
        id,
        status: 'ready',
        title: 'Empty transcript preview',
        transcript: [],
      };
    }

    return audioFiles.find((file) => file.id === id);
  },
  async renameAudioFile(id: string, title: string) {
    const nativeFile = await withNative<AudioFile>((nativeModule) =>
      nativeModule.renameAudioFile?.(id, title),
    );

    if (nativeFile) {
      return nativeFile;
    }

    const trimmedTitle = title.trim();
    if (!trimmedTitle) {
      return undefined;
    }

    const generatedFile = fallbackGeneratedFiles.find((file) => file.id === id);
    if (!generatedFile) {
      return undefined;
    }

    const renamedFile = { ...generatedFile, title: trimmedTitle };
    upsertFallbackGeneratedFile(renamedFile);
    return renamedFile;
  },
  async moveAudioFile(id: string, projectId: string | null) {
    const nativeFile = await withNative<AudioFile>((nativeModule) =>
      nativeModule.moveAudioFile?.(id, projectId),
    );

    if (nativeFile) {
      return nativeFile;
    }

    const generatedFile = fallbackGeneratedFiles.find((file) => file.id === id);
    if (!generatedFile) {
      return undefined;
    }

    const movedFile = { ...generatedFile, project: projectId?.trim() || 'Inbox' };
    upsertFallbackGeneratedFile(movedFile);
    return movedFile;
  },
  async deleteAudioFile(id: string) {
    const nativeDeleted = await withNative<boolean>((nativeModule) =>
      nativeModule.deleteAudioFile?.(id),
    );

    if (nativeDeleted) {
      return true;
    }

    const previousLength = fallbackGeneratedFiles.length;
    fallbackGeneratedFiles = fallbackGeneratedFiles.filter((file) => file.id !== id);
    return fallbackGeneratedFiles.length !== previousLength;
  },
  async enqueueProcessingRetry(request: ProcessingRetryRequestDTO) {
    const nativeItem = await withNative<ProcessingRetryDTO>((nativeModule) =>
      nativeModule.enqueueProcessingRetry?.(request),
    );
    if (nativeItem) return nativeItem;

    const now = new Date().toISOString();
    const existing = fallbackProcessingRetries.find(
      (item) => item.audioFileId === request.audioFileId && item.operation === request.operation,
    );
    if (existing) {
      const updated = {
        ...existing,
        lastError: request.lastError?.trim() ?? '',
        updatedAt: now,
      };
      fallbackProcessingRetries = fallbackProcessingRetries.map((item) =>
        item.id === updated.id ? updated : item,
      );
      return updated;
    }

    const item: ProcessingRetryDTO = {
      ...request,
      attemptCount: 0,
      createdAt: now,
      id: `retry-${Date.now()}`,
      lastError: request.lastError?.trim() ?? '',
      updatedAt: now,
    };
    fallbackProcessingRetries.push(item);
    return item;
  },
  async listProcessingRetries() {
    const nativeItems = await withNative<ProcessingRetryDTO[]>((nativeModule) =>
      nativeModule.listProcessingRetries?.(),
    );
    return nativeItems ?? [...fallbackProcessingRetries];
  },
  async recordProcessingRetryFailure(id: string, lastError: string) {
    const nativeItem = await withNative<ProcessingRetryDTO>((nativeModule) =>
      nativeModule.recordProcessingRetryFailure?.(id, lastError),
    );
    if (nativeItem) return nativeItem;

    const existing = fallbackProcessingRetries.find((item) => item.id === id);
    if (!existing) return undefined;
    const updated = {
      ...existing,
      attemptCount: existing.attemptCount + 1,
      lastError: lastError.trim(),
      updatedAt: new Date().toISOString(),
    };
    fallbackProcessingRetries = fallbackProcessingRetries.map((item) =>
      item.id === id ? updated : item,
    );
    return updated;
  },
  async completeProcessingRetry(id: string) {
    const nativeCompleted = await withNative<boolean>((nativeModule) =>
      nativeModule.completeProcessingRetry?.(id),
    );
    if (nativeCompleted) return true;

    const previousLength = fallbackProcessingRetries.length;
    fallbackProcessingRetries = fallbackProcessingRetries.filter((item) => item.id !== id);
    return fallbackProcessingRetries.length !== previousLength;
  },
  async startRecording() {
    const nativeSession = await withNative((nativeModule) => nativeModule.startRecording?.());

    if (nativeSession) {
      return nativeSession;
    }

    return {
      id: `recording-${Date.now()}`,
      startedAt: new Date().toISOString(),
      source: 'iPhone',
    };
  },
  async pauseRecording(sessionId: string) {
    await withNative<void>((nativeModule) => nativeModule.pauseRecording?.(sessionId));
  },
  async resumeRecording(sessionId: string) {
    await withNative<void>((nativeModule) => nativeModule.resumeRecording?.(sessionId));
  },
  async discardRecording(sessionId: string) {
    await withNative<void>((nativeModule) => nativeModule.discardRecording?.(sessionId));
  },
  async stopRecording(sessionId: string) {
    const nativeFile = await withNative<AudioFile>((nativeModule) =>
      nativeModule.stopRecording?.(sessionId),
    );

    if (nativeFile) {
      return nativeFile;
    }

    const generatedFile = createGeneratedFile(`${sessionId}.m4a`);
    upsertFallbackGeneratedFile(generatedFile);
    return generatedFile;
  },
  async importAudio(uri: string) {
    const nativeFile = await withNative<AudioFile>((nativeModule) =>
      nativeModule.importAudio?.(uri),
    );

    if (nativeFile) {
      return nativeFile;
    }

    const generatedFile = createGeneratedFile(uri);
    upsertFallbackGeneratedFile(generatedFile);
    return generatedFile;
  },
  async startTranscription(audioFileId: string): Promise<TranscriptionTaskDTO> {
    const nativeTask = await withNative<TranscriptionTaskDTO>((nativeModule) =>
      nativeModule.startTranscription?.(audioFileId),
    );

    if (nativeTask) {
      return nativeTask;
    }

    const task: TranscriptionTaskDTO = {
      id: `transcription-${audioFileId}-${Date.now()}`,
      audioFileId,
      status: 'running',
      progress: 0,
    };

    let progress = 0;
    emit({
      audioFileId,
      message: '文字起こしを開始しました',
      progress,
      taskId: task.id,
      type: 'started',
    });

    const timer = setInterval(() => {
      progress = Math.min(progress + 0.2, 1);
      emit({
        audioFileId,
        message: progress >= 1 ? '文字起こしが完了しました' : 'チャンクを処理中です',
        progress,
        taskId: task.id,
        type: progress >= 1 ? 'completed' : 'progress',
      });

      if (progress >= 1) {
        clearInterval(timer);
        timers.delete(task.id);
      }
    }, 650);

    timers.set(task.id, timer);
    return task;
  },
  async cancelTranscription(taskId: string) {
    const cancelledByNative = await withNative(async (nativeModule) => {
      if (!nativeModule.cancelTranscription) {
        return undefined;
      }

      await nativeModule.cancelTranscription(taskId);
      return true;
    });

    if (cancelledByNative) {
      return;
    }

    const timer = timers.get(taskId);
    if (timer) {
      clearInterval(timer);
      timers.delete(taskId);
    }
    emit({
      audioFileId: '',
      message: '文字起こしをキャンセルしました',
      progress: 0,
      taskId,
      type: 'cancelled',
    });
  },
  addTranscriptionListener(taskId, listener) {
    const nativeModule = loadNativeModule();
    const nativeSubscription = nativeModule?.addListener?.('onTranscriptionEvent', (event) => {
      if (event.taskId === taskId) {
        listener(event);
      }
    });

    const mockSubscription = addListener(taskId, listener);

    return {
      remove() {
        nativeSubscription?.remove();
        mockSubscription.remove();
      },
    };
  },
  async generateSummary(request: SummaryRequestDTO) {
    const nativeResponse = await withNative<SummaryDTO>((nativeModule) =>
      nativeModule.generateSummary?.(request),
    );

    if (nativeResponse) {
      return nativeResponse;
    }

    const { audioFileId, options } = request;
    const file = audioFiles.find((item) => item.id === audioFileId);
    return {
      audioFileId,
      generatedAt: new Date().toISOString(),
      provider: options.provider,
      text: file?.summary ?? '要約対象のファイルが見つかりません。',
    };
  },
  async queryKnowledge(request: KnowledgeQueryRequestDTO) {
    const nativeResponse = await withNative<KnowledgeQueryResponseDTO>((nativeModule) =>
      nativeModule.queryKnowledge?.(request),
    );

    return nativeResponse ?? createFallbackKnowledgeResponse(request);
  },
  async loadSettings() {
    const nativeSettings = await withNative<SettingsDTO>((nativeModule) =>
      nativeModule.loadSettings?.(),
    );

    return nativeSettings ?? loadFallbackSettings();
  },
  async saveSettings(nextSettings: SettingsDTO) {
    const savedByNative = await withNative(async (nativeModule) => {
      if (!nativeModule.saveSettings) {
        return undefined;
      }

      await nativeModule.saveSettings(nextSettings);
      return true;
    });

    if (savedByNative) {
      saveFallbackSettings(nextSettings);
      return;
    }

    saveFallbackSettings(nextSettings);
  },
  async getBridgeInfo() {
    const nativeInfo = await withNative<BridgeInfoDTO>((nativeModule) =>
      nativeModule.getBridgeInfo?.(),
    );

    return (
      nativeInfo ?? {
        audioFileMutationSource: 'mock',
        audioFileSource: 'mock',
        isRealDataConnected: false,
        knowledgeQuerySource: 'mock',
        moduleName: 'MemoraNative',
        moduleVersion: '1.0.0',
        platform: Platform.OS === 'web' ? 'web' : 'unknown',
        persistenceScope: 'mock',
        recordingSource: 'mock',
        retryQueueSource: 'mock',
        settingsSource: 'mock',
        summarySource: 'mock',
      }
    );
  },
  async loadPlayback(audioFileId: string) {
    const nativeStatus = await withNative<PlaybackStatusDTO>((nativeModule) =>
      nativeModule.loadPlayback?.(audioFileId),
    );

    if (nativeStatus) {
      fallbackPlayback = undefined;
      return nativeStatus;
    }

    stopFallbackPlaybackTimer();
    fallbackPlayback = { audioFileId, isPlaying: false, position: 0, duration: 12, rate: 1 };
    return fallbackPlayback;
  },
  async playPlayback() {
    const nativeStatus = await withNative<PlaybackStatusDTO>((nativeModule) =>
      nativeModule.playPlayback?.(),
    );

    if (nativeStatus) {
      return nativeStatus;
    }

    if (!fallbackPlayback) {
      throw new Error('この録音には再生可能な音声ファイルがありません。');
    }

    fallbackPlayback = { ...fallbackPlayback, isPlaying: true };
    stopFallbackPlaybackTimer();
    fallbackPlaybackTimer = setInterval(() => {
      if (!fallbackPlayback) return;
      const nextPosition = Math.min(fallbackPlayback.position + 0.25 * fallbackPlayback.rate, fallbackPlayback.duration);
      fallbackPlayback = {
        ...fallbackPlayback,
        position: nextPosition,
        isPlaying: nextPosition < fallbackPlayback.duration,
      };
      if (nextPosition >= fallbackPlayback.duration) {
        stopFallbackPlaybackTimer();
      }
    }, 250);
    return fallbackPlayback;
  },
  async pausePlayback() {
    const nativeStatus = await withNative<PlaybackStatusDTO>((nativeModule) =>
      nativeModule.pausePlayback?.(),
    );

    if (nativeStatus) {
      return nativeStatus;
    }

    stopFallbackPlaybackTimer();
    if (!fallbackPlayback) {
      throw new Error('この録音には再生可能な音声ファイルがありません。');
    }
    fallbackPlayback = { ...fallbackPlayback, isPlaying: false };
    return fallbackPlayback;
  },
  async seekPlayback(position: number) {
    const nativeStatus = await withNative<PlaybackStatusDTO>((nativeModule) =>
      nativeModule.seekPlayback?.(position),
    );

    if (nativeStatus) {
      return nativeStatus;
    }

    if (!fallbackPlayback) {
      throw new Error('この録音には再生可能な音声ファイルがありません。');
    }
    fallbackPlayback = {
      ...fallbackPlayback,
      position: Math.max(0, Math.min(position, fallbackPlayback.duration)),
    };
    return fallbackPlayback;
  },
  async setPlaybackRate(rate: number) {
    const nativeStatus = await withNative<PlaybackStatusDTO>((nativeModule) =>
      nativeModule.setPlaybackRate?.(rate),
    );

    if (nativeStatus) {
      return nativeStatus;
    }

    if (!fallbackPlayback) {
      throw new Error('この録音には再生可能な音声ファイルがありません。');
    }
    fallbackPlayback = { ...fallbackPlayback, rate };
    return fallbackPlayback;
  },
  async getPlaybackStatus() {
    const nativeStatus = await withNative<PlaybackStatusDTO>((nativeModule) =>
      nativeModule.getPlaybackStatus?.(),
    );

    return nativeStatus ?? fallbackPlayback;
  },
  async getMemoDraft(audioFileId: string) {
    const nativeDraft = await withNative<string>((nativeModule) =>
      nativeModule.getMemoDraft?.(audioFileId),
    );

    if (nativeDraft !== undefined) {
      return nativeDraft;
    }

    return fallbackMemoRecord(audioFileId).text;
  },
  async saveMemoDraft(audioFileId: string, text: string) {
    const savedByNative = await withNative(async (nativeModule) => {
      if (!nativeModule.saveMemoDraft) return undefined;
      await nativeModule.saveMemoDraft(audioFileId, text);
      return true;
    });

    if (savedByNative) {
      return;
    }

    fallbackMemoRecord(audioFileId).text = text;
  },
  async listPhotoAttachments(audioFileId: string) {
    const nativeAttachments = await withNative<PhotoAttachmentDTO[]>((nativeModule) =>
      nativeModule.listPhotoAttachments?.(audioFileId),
    );

    if (nativeAttachments) {
      return nativeAttachments;
    }

    return fallbackMemoRecord(audioFileId).photos;
  },
  async addPhotoAttachment(audioFileId: string, sourceUri: string) {
    const nativeAttachment = await withNative<PhotoAttachmentDTO>((nativeModule) =>
      nativeModule.addPhotoAttachment?.(audioFileId, sourceUri),
    );

    if (nativeAttachment) {
      return nativeAttachment;
    }

    const record = fallbackMemoRecord(audioFileId);
    const attachment: PhotoAttachmentDTO = {
      id: `photo-${Date.now()}`,
      uri: sourceUri,
      addedAt: new Date().toISOString(),
    };
    record.photos = [...record.photos, attachment];
    return attachment;
  },
  async deletePhotoAttachment(audioFileId: string, attachmentId: string) {
    const nativeDeleted = await withNative<boolean>((nativeModule) =>
      nativeModule.deletePhotoAttachment?.(audioFileId, attachmentId),
    );

    if (nativeDeleted) {
      return true;
    }

    const record = fallbackMemoRecord(audioFileId);
    const previousLength = record.photos.length;
    record.photos = record.photos.filter((photo) => photo.id !== attachmentId);
    return record.photos.length !== previousLength;
  },
};
