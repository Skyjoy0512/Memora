export type AudioFileDTO = {
  id: string;
  title: string;
  project: string;
  source: 'iPhone' | 'PLAUD' | 'Omi' | 'Google Meet';
  recordedAt: string;
  duration: string;
  status: 'ready' | 'transcribing' | 'failed' | 'summarized';
  summary: string;
  transcript: Array<{
    id: string;
    speaker: string;
    time: string;
    text: string;
    confidence: number;
  }>;
  memo: string[];
};

export type TranscriptionTaskDTO = {
  id: string;
  audioFileId: string;
  status: 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';
  progress: number;
};

export type RecordingSessionDTO = {
  id: string;
  startedAt: string;
  source: 'iPhone';
};

export type TranscriptionEventDTO = {
  taskId: string;
  audioFileId: string;
  type: 'started' | 'progress' | 'completed' | 'failed' | 'cancelled';
  progress: number;
  message: string;
};

export type BridgeInfoDTO = {
  platform: 'ios' | 'web' | 'android' | 'unknown';
  moduleName: string;
  moduleVersion: string;
  audioFileSource: 'sample' | 'native-files' | 'swiftdata' | 'mock' | 'unknown';
  audioFileMutationSource: 'sample' | 'native-files' | 'swiftdata' | 'mock' | 'unknown';
  recordingSource: 'sample' | 'native' | 'native-file' | 'mock' | 'unknown';
  settingsSource: 'memory' | 'userdefaults' | 'keychain' | 'mock' | 'unknown';
  knowledgeQuerySource: 'sample' | 'native' | 'swiftdata' | 'mock' | 'unknown';
  summarySource: 'sample' | 'native' | 'swiftdata' | 'mock' | 'unknown';
  retryQueueSource: 'native-file' | 'mock' | 'unknown';
  persistenceScope: 'app-sandbox' | 'app-group' | 'shared-swiftdata' | 'mock' | 'unknown';
  isRealDataConnected: boolean;
};

export type SettingsDTO = {
  transcriptionMode: 'local' | 'api';
  summaryProvider: 'OpenAI' | 'Gemini' | 'DeepSeek' | 'Local';
  speechAnalyzerEnabled: boolean;
};

export type KnowledgeQueryScope = 'file' | 'project' | 'global';

export type KnowledgeQueryRequestDTO = {
  scope: KnowledgeQueryScope;
  question: string;
  audioFileId?: string;
  projectId?: string;
};

export type KnowledgeQueryResponseDTO = {
  id: string;
  answer: string;
  sources: string[];
  scope: KnowledgeQueryScope;
  answeredAt: string;
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

export type MemoraNativeModuleEvents = {
  onTranscriptionEvent: (params: TranscriptionEventDTO) => void;
};
