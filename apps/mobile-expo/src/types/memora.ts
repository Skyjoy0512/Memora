export type AudioStatus = 'queued' | 'ready' | 'transcribing' | 'failed' | 'summarized';

export type TranscriptSegment = {
  id: string;
  speaker: string;
  time: string;
  text: string;
  cleanedText?: string;
  confidence: number;
};

export type AudioFile = {
  id: string;
  title: string;
  project: string;
  source: 'iPhone' | 'PLAUD' | 'Omi' | 'Google Meet';
  recordedAt: string;
  duration: string;
  status: AudioStatus;
  summary: string;
  transcript: TranscriptSegment[];
  memo: string[];
};

export type SettingsGroup = {
  title: string;
  description: string;
  items: Array<{
    label: string;
    value: string;
    state?: 'ok' | 'warning' | 'off';
  }>;
};

export type AskMessage = {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  sources?: string[];
};
