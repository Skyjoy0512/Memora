import type { AudioFile } from '../types/memora';

export type BridgeSubscription = {
  remove: () => void;
};

export type RecordingSessionDTO = {
  id: string;
  startedAt: string;
  source: 'iPhone';
};

export type TranscriptionTaskDTO = {
  id: string;
  audioFileId: string;
  status: 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';
  progress: number;
};

export type TranscriptionEventDTO = {
  taskId: string;
  audioFileId: string;
  type: 'started' | 'progress' | 'completed' | 'failed' | 'cancelled';
  progress: number;
  message: string;
};

export type SummaryOptionsDTO = {
  provider: 'OpenAI' | 'Gemini' | 'DeepSeek' | 'Local';
  templateId?: string;
};

export type SummaryRequestDTO = {
  audioFileId: string;
  options: SummaryOptionsDTO;
};

export type SummaryDTO = {
  audioFileId: string;
  text: string;
  generatedAt: string;
  provider: SummaryOptionsDTO['provider'];
};

export type ProcessingRetryOperation = 'transcription' | 'summary';

export type ProcessingRetryRequestDTO = {
  audioFileId: string;
  operation: ProcessingRetryOperation;
  lastError?: string;
};

export type ProcessingRetryDTO = ProcessingRetryRequestDTO & {
  id: string;
  attemptCount: number;
  lastError: string;
  createdAt: string;
  updatedAt: string;
};

export type SettingsDTO = {
  transcriptionMode: 'local' | 'api';
  summaryProvider: SummaryOptionsDTO['provider'];
  speechAnalyzerEnabled: boolean;
};

export type CustomVocabularyDTO = {
  id: string;
  pattern: string;
  replacement: string;
  reading?: string | null;
  enabled: boolean;
  createdAt: string;
};

export type KnowledgeQueryScope = 'file' | 'project' | 'global';

export type KnowledgeQueryRequestDTO = {
  scope: KnowledgeQueryScope;
  question: string;
  audioFileId?: string;
  projectId?: string;
  sessionId?: string;
};

export type KnowledgeQueryResponseDTO = {
  id: string;
  answer: string;
  sources: string[];
  sessionId: string;
  scope: KnowledgeQueryScope;
  answeredAt: string;
};

export type PlaybackStatusDTO = {
  audioFileId: string;
  isPlaying: boolean;
  position: number;
  duration: number;
  rate: number;
};

export type PhotoAttachmentDTO = {
  id: string;
  uri: string;
  addedAt: string;
};

export type BridgeInfoDTO = {
  platform: 'ios' | 'web' | 'android' | 'unknown';
  moduleName: string;
  moduleVersion: string;
  audioFileSource: 'sample' | 'native-files' | 'swiftdata' | 'mock' | 'unknown';
  audioFileMutationSource: 'sample' | 'native-files' | 'swiftdata' | 'mock' | 'unknown';
  recordingSource: 'sample' | 'native' | 'native-file' | 'swiftdata' | 'mock' | 'unknown';
  settingsSource: 'memory' | 'userdefaults' | 'keychain' | 'mock' | 'unknown';
  knowledgeQuerySource: 'sample' | 'native' | 'swiftdata' | 'mock' | 'unknown';
  summarySource: 'sample' | 'native' | 'swiftdata' | 'mock' | 'unknown';
  retryQueueSource: 'native-file' | 'mock' | 'unknown';
  persistenceScope: 'app-sandbox' | 'app-group' | 'shared-swiftdata' | 'mock' | 'unknown';
  isRealDataConnected: boolean;
};

export type MemoraNativeModule = {
  listAudioFiles: () => Promise<AudioFile[]>;
  getAudioFile: (id: string) => Promise<AudioFile | undefined>;
  renameAudioFile: (id: string, title: string) => Promise<AudioFile | undefined>;
  moveAudioFile: (id: string, projectId: string | null) => Promise<AudioFile | undefined>;
  deleteAudioFile: (id: string) => Promise<boolean>;
  enqueueProcessingRetry: (request: ProcessingRetryRequestDTO) => Promise<ProcessingRetryDTO>;
  listProcessingRetries: () => Promise<ProcessingRetryDTO[]>;
  recordProcessingRetryFailure: (
    id: string,
    lastError: string,
  ) => Promise<ProcessingRetryDTO | undefined>;
  completeProcessingRetry: (id: string) => Promise<boolean>;
  startRecording: () => Promise<RecordingSessionDTO>;
  pauseRecording: (sessionId: string) => Promise<void>;
  resumeRecording: (sessionId: string) => Promise<void>;
  discardRecording: (sessionId: string) => Promise<void>;
  stopRecording: (sessionId: string) => Promise<AudioFile>;
  importAudio: (uri: string) => Promise<AudioFile>;
  startTranscription: (audioFileId: string) => Promise<TranscriptionTaskDTO>;
  cancelTranscription: (taskId: string) => Promise<void>;
  addTranscriptionListener: (
    taskId: string,
    listener: (event: TranscriptionEventDTO) => void,
  ) => BridgeSubscription;
  generateSummary: (request: SummaryRequestDTO) => Promise<SummaryDTO>;
  getSecureCredentialStatus: (provider: SummaryOptionsDTO['provider']) => Promise<boolean>;
  deleteSecureCredential: (provider: SummaryOptionsDTO['provider']) => Promise<boolean>;
  presentSecureCredentialInput: (provider: SummaryOptionsDTO['provider']) => Promise<boolean>;
  queryKnowledge: (request: KnowledgeQueryRequestDTO) => Promise<KnowledgeQueryResponseDTO>;
  loadSettings: () => Promise<SettingsDTO>;
  saveSettings: (settings: SettingsDTO) => Promise<void>;
  listCustomVocabulary: () => Promise<CustomVocabularyDTO[]>;
  saveCustomVocabulary: (value: CustomVocabularyDTO) => Promise<CustomVocabularyDTO>;
  deleteCustomVocabulary: (id: string) => Promise<boolean>;
  setCustomVocabularyEnabled: (id: string, enabled: boolean) => Promise<CustomVocabularyDTO | undefined>;
  getBridgeInfo: () => Promise<BridgeInfoDTO>;
  loadPlayback: (audioFileId: string) => Promise<PlaybackStatusDTO>;
  playPlayback: () => Promise<PlaybackStatusDTO>;
  pausePlayback: () => Promise<PlaybackStatusDTO>;
  seekPlayback: (position: number) => Promise<PlaybackStatusDTO>;
  setPlaybackRate: (rate: number) => Promise<PlaybackStatusDTO>;
  getPlaybackStatus: () => Promise<PlaybackStatusDTO | undefined>;
  getMemoDraft: (audioFileId: string) => Promise<string>;
  saveMemoDraft: (audioFileId: string, text: string) => Promise<void>;
  listPhotoAttachments: (audioFileId: string) => Promise<PhotoAttachmentDTO[]>;
  addPhotoAttachment: (audioFileId: string, sourceUri: string) => Promise<PhotoAttachmentDTO>;
  deletePhotoAttachment: (audioFileId: string, attachmentId: string) => Promise<boolean>;
};
