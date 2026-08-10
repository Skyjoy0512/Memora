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
  tasksSource: 'memory' | 'swiftdata' | 'mock' | 'unknown';
  taskMutationSource: 'memory' | 'swiftdata' | 'mock' | 'unknown';
  persistenceScope: 'app-sandbox' | 'app-group' | 'shared-swiftdata' | 'sandbox-swiftdata' | 'mock' | 'unknown';
  storeMode?: 'app-group' | 'app-sandbox';
  sharedStoreError?: string;
  isRealDataConnected: boolean;
};

export type SettingsDTO = {
  transcriptionMode: 'local' | 'api';
  summaryProvider: 'OpenAI' | 'Gemini' | 'DeepSeek' | 'Local';
  speechAnalyzerEnabled: boolean;
  /** Notion 書き出し先の親ページ（URL またはページID）。認証情報ではなく設定として保存する。 */
  notionParentPage: string;
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

export type ExportDestination = 'notion' | 'chatgpt' | 'file';

export type ExportPayloadDTO = {
  title: string;
  /** summary + transcript を結合した Markdown テキスト */
  text: string;
  createdAt?: string;
  sourceFileId: string;
  destination: ExportDestination;
};

export type ExportResultDTO = {
  ok: boolean;
  destination: ExportDestination;
  /** Notion page id 等。成功時に設定される */
  refId?: string;
  error?: string;
};

export type SecureCredentialProvider = SummaryOptionsDTO['provider'] | 'Notion';

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

export type TaskDTO = {
  id: string;
  title: string;
  notes?: string | null;
  assignee?: string | null;
  speaker?: string | null;
  priority: string;
  dueDate?: string | null;
  relativeDueDate?: string | null;
  projectId?: string | null;
  parentId?: string | null;
  sourceAudioFileId?: string | null;
  isCompleted: boolean;
  createdAt: string;
  completedAt?: string | null;
};

export type ProjectDTO = {
  id: string;
  title: string;
};

export type MemoraNativeModuleEvents = {
  onTranscriptionEvent: (params: TranscriptionEventDTO) => void;
};
