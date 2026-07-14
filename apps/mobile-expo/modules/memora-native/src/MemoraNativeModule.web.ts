import { registerWebModule, NativeModule } from 'expo';

import {
  AudioFileDTO,
  BridgeInfoDTO,
  KnowledgeQueryRequestDTO,
  KnowledgeQueryResponseDTO,
  MemoraNativeModuleEvents,
  ProcessingRetryDTO,
  ProcessingRetryRequestDTO,
  RecordingSessionDTO,
  SettingsDTO,
  SummaryDTO,
  SummaryRequestDTO,
  TranscriptionTaskDTO,
} from './MemoraNative.types';

class MemoraNativeModule extends NativeModule<MemoraNativeModuleEvents> {
  private retries: ProcessingRetryDTO[] = [];

  async listAudioFiles(): Promise<AudioFileDTO[]> {
    return [];
  }

  async getAudioFile(): Promise<AudioFileDTO | null> {
    return null;
  }

  async renameAudioFile(): Promise<AudioFileDTO | null> {
    return null;
  }

  async moveAudioFile(): Promise<AudioFileDTO | null> {
    return null;
  }

  async deleteAudioFile(): Promise<boolean> {
    return false;
  }

  async enqueueProcessingRetry(request: ProcessingRetryRequestDTO): Promise<ProcessingRetryDTO> {
    const existing = this.retries.find(
      (item) => item.audioFileId === request.audioFileId && item.operation === request.operation,
    );
    const now = new Date().toISOString();
    if (existing) {
      existing.lastError = request.lastError?.trim() ?? '';
      existing.updatedAt = now;
      return existing;
    }
    const item: ProcessingRetryDTO = {
      ...request,
      attemptCount: 0,
      createdAt: now,
      id: `web-retry-${Date.now()}`,
      lastError: request.lastError?.trim() ?? '',
      updatedAt: now,
    };
    this.retries.push(item);
    return item;
  }

  async listProcessingRetries(): Promise<ProcessingRetryDTO[]> {
    return [...this.retries];
  }

  async recordProcessingRetryFailure(
    id: string,
    lastError: string,
  ): Promise<ProcessingRetryDTO | null> {
    const item = this.retries.find((retry) => retry.id === id);
    if (!item) return null;
    item.attemptCount += 1;
    item.lastError = lastError.trim();
    item.updatedAt = new Date().toISOString();
    return item;
  }

  async completeProcessingRetry(id: string): Promise<boolean> {
    const previousLength = this.retries.length;
    this.retries = this.retries.filter((retry) => retry.id !== id);
    return this.retries.length !== previousLength;
  }

  async getBridgeInfo(): Promise<BridgeInfoDTO> {
    return {
      audioFileMutationSource: 'mock',
      audioFileSource: 'mock',
      isRealDataConnected: false,
      knowledgeQuerySource: 'mock',
      moduleName: 'MemoraNative',
      moduleVersion: '1.0.0',
      platform: 'web',
      persistenceScope: 'mock',
      recordingSource: 'mock',
      retryQueueSource: 'mock',
      settingsSource: 'mock',
      summarySource: 'mock',
    };
  }

  async loadSettings(): Promise<SettingsDTO> {
    return {
      speechAnalyzerEnabled: false,
      summaryProvider: 'Gemini',
      transcriptionMode: 'local',
    };
  }

  async saveSettings(): Promise<void> {}

  async startRecording(): Promise<RecordingSessionDTO> {
    return {
      id: `web-recording-${Date.now()}`,
      source: 'iPhone',
      startedAt: new Date().toISOString(),
    };
  }

  async pauseRecording(): Promise<void> {}

  async resumeRecording(): Promise<void> {}

  async discardRecording(): Promise<void> {}

  async stopRecording(sessionId: string): Promise<AudioFileDTO> {
    return this.makeGeneratedFile(`${sessionId}.m4a`);
  }

  async importAudio(uri: string): Promise<AudioFileDTO> {
    return this.makeGeneratedFile(uri);
  }

  async startTranscription(audioFileId: string): Promise<TranscriptionTaskDTO> {
    return {
      audioFileId,
      id: `web-task-${Date.now()}`,
      progress: 0,
      status: 'queued',
    };
  }

  async cancelTranscription(): Promise<void> {}

  async queryKnowledge(request: KnowledgeQueryRequestDTO): Promise<KnowledgeQueryResponseDTO> {
    return {
      answer: this.makeKnowledgeAnswer(request.scope),
      answeredAt: new Date().toISOString(),
      id: `web-query-${Date.now()}`,
      scope: request.scope,
      sources: this.makeKnowledgeSources(request.scope),
    };
  }

  async generateSummary(request: SummaryRequestDTO): Promise<SummaryDTO> {
    return {
      audioFileId: request.audioFileId,
      generatedAt: new Date().toISOString(),
      provider: request.options.provider,
      text: 'Web fallback summary: bridge contract is ready for the host-app summarizer.',
    };
  }

  private makeGeneratedFile(sourceUri: string): AudioFileDTO {
    return {
      duration: '00:00',
      id: `native-web-import-${Date.now()}`,
      memo: [],
      project: 'Inbox',
      recordedAt: 'web',
      source: 'iPhone',
      status: 'ready',
      summary: 'Web fallback generated this DTO without using native recording services.',
      title: sourceUri.split('/').pop() ?? 'Imported audio',
      transcript: [],
    };
  }

  private makeKnowledgeAnswer(scope: KnowledgeQueryRequestDTO['scope']): string {
    if (scope === 'file') {
      return 'このファイルでは、Expo mock UI を先に固めてから native bridge を薄く足す方針が安全です。';
    }

    if (scope === 'project') {
      return 'プロジェクト全体では、画面レビューとbridge境界の検証を分けて進めるのが次の優先です。';
    }

    return '全体横断では、STT保護境界、既存バックエンド維持、Dev Client確認が重要です。';
  }

  private makeKnowledgeSources(scope: KnowledgeQueryRequestDTO['scope']): string[] {
    if (scope === 'file') {
      return ['Growth 定例', 'File Detail memo'];
    }

    if (scope === 'project') {
      return ['React Native / Expo Migration Plan', 'Bridge Contract'];
    }

    return ['Migration handoff', 'Settings bridge diagnostics'];
  }
}

export default registerWebModule(MemoraNativeModule, 'MemoraNative');
