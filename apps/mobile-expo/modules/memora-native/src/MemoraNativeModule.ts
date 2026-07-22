import { NativeModule, requireNativeModule } from 'expo';

import {
  AudioFileDTO,
  BridgeInfoDTO,
  CustomVocabularyDTO,
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

declare class MemoraNativeModule extends NativeModule<MemoraNativeModuleEvents> {
  listAudioFiles(): Promise<AudioFileDTO[]>;
  getAudioFile(id: string): Promise<AudioFileDTO | null>;
  renameAudioFile(id: string, title: string): Promise<AudioFileDTO | null>;
  moveAudioFile(id: string, projectId: string | null): Promise<AudioFileDTO | null>;
  deleteAudioFile(id: string): Promise<boolean>;
  getBridgeInfo(): Promise<BridgeInfoDTO>;
  loadSettings(): Promise<SettingsDTO>;
  saveSettings(settings: SettingsDTO): Promise<void>;
  listCustomVocabulary(): Promise<CustomVocabularyDTO[]>;
  saveCustomVocabulary(value: CustomVocabularyDTO): Promise<CustomVocabularyDTO>;
  deleteCustomVocabulary(id: string): Promise<boolean>;
  setCustomVocabularyEnabled(id: string, enabled: boolean): Promise<CustomVocabularyDTO | null>;
  startRecording(): Promise<RecordingSessionDTO>;
  pauseRecording(sessionId: string): Promise<void>;
  resumeRecording(sessionId: string): Promise<void>;
  discardRecording(sessionId: string): Promise<void>;
  stopRecording(sessionId: string): Promise<AudioFileDTO>;
  importAudio(uri: string): Promise<AudioFileDTO>;
  startTranscription(audioFileId: string): Promise<TranscriptionTaskDTO>;
  cancelTranscription(taskId: string): Promise<void>;
  queryKnowledge(request: KnowledgeQueryRequestDTO): Promise<KnowledgeQueryResponseDTO>;
  generateSummary(request: SummaryRequestDTO): Promise<SummaryDTO>;
  getSecureCredentialStatus(provider: SummaryRequestDTO['options']['provider']): Promise<boolean>;
  deleteSecureCredential(provider: SummaryRequestDTO['options']['provider']): Promise<boolean>;
  presentSecureCredentialInput(provider: SummaryRequestDTO['options']['provider']): Promise<boolean>;
  enqueueProcessingRetry(request: ProcessingRetryRequestDTO): Promise<ProcessingRetryDTO>;
  listProcessingRetries(): Promise<ProcessingRetryDTO[]>;
  recordProcessingRetryFailure(id: string, lastError: string): Promise<ProcessingRetryDTO | null>;
  completeProcessingRetry(id: string): Promise<boolean>;
}

export default requireNativeModule<MemoraNativeModule>('MemoraNative');
