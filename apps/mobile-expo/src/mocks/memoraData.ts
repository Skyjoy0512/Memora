import type { AskMessage, AudioFile, SettingsGroup } from '../types/memora';

export const audioFiles: AudioFile[] = [
  {
    id: 'weekly-growth-0709',
    title: 'Growth 定例: 7月施策レビュー',
    project: 'Memora Launch',
    source: 'iPhone',
    recordedAt: '今日 10:02',
    duration: '48:12',
    status: 'summarized',
    summary:
      'オンボーディングの離脱点、録音後の要約生成、PLAUD 取り込み導線を優先改善する方針。次回までに Expo UI mock を使って主要画面の確認ループを作る。',
    transcript: [
      {
        id: 't1',
        speaker: 'Speaker 1',
        time: '00:12',
        text: 'まず録音後の体験を、一覧から詳細まで一気通貫で見直したいです。',
        confidence: 0.94,
      },
      {
        id: 't2',
        speaker: 'Speaker 2',
        time: '01:04',
        text: 'STT コアは触らず、UI 側で進捗と失敗状態を分かりやすく出すのが安全です。',
        confidence: 0.91,
      },
      {
        id: 't3',
        speaker: 'Speaker 1',
        time: '03:36',
        text: 'Expo で細かく見ながら修正できるなら、SwiftUI の重さからかなり解放されそうです。',
        confidence: 0.96,
      },
    ],
    memo: [
      'Expo mock UI を先に作る',
      'Native bridge は read-only から始める',
      'STT 保護ファイルは移行対象外',
    ],
  },
  {
    id: 'plaud-import-test',
    title: 'PLAUD import 検証',
    project: 'Device Integrations',
    source: 'PLAUD',
    recordedAt: '昨日 16:44',
    duration: '27:08',
    status: 'transcribing',
    summary: 'PLAUD 取り込み後のメタデータ表示、話者ラベル、失敗時の再試行導線を確認中。',
    transcript: [
      {
        id: 'p1',
        speaker: 'Speaker 1',
        time: '00:08',
        text: 'インポート後にすぐ詳細へ入れる導線があると自然です。',
        confidence: 0.88,
      },
    ],
    memo: ['取り込み完了通知', 'ファイル詳細への自動遷移', '失敗時の原因表示'],
  },
  {
    id: 'meet-sales-sync',
    title: 'Sales sync / bot recording',
    project: 'Bot Server',
    source: 'Google Meet',
    recordedAt: '7月8日 11:30',
    duration: '1:12:41',
    status: 'failed',
    summary: 'Bot server の録音取得は成功。iOS 側の webhook 復帰後ステータス表示を改善する必要あり。',
    transcript: [],
    memo: ['Webhook retry', 'S3 URL expiry', '失敗状態の復元'],
  },
];

export const settingsGroups: SettingsGroup[] = [
  {
    title: '文字起こしと AI',
    description: '既存 Swift core を維持し、RN からは設定と状態だけを扱う。',
    items: [
      { label: 'Transcription mode', value: 'Local first', state: 'ok' },
      { label: 'Summary provider', value: 'Gemini', state: 'ok' },
      { label: 'SpeechAnalyzer', value: 'Feature flag off', state: 'warning' },
    ],
  },
  {
    title: 'デバイス連携',
    description: 'PLAUD / Omi / Generic recorder の導線を統合する。',
    items: [
      { label: 'PLAUD import', value: 'Connected', state: 'ok' },
      { label: 'Omi preview', value: 'Experimental', state: 'warning' },
      { label: 'Generic BLE', value: 'Bridge pending', state: 'off' },
    ],
  },
  {
    title: 'React Native 移行',
    description: 'Expo Go は mock UI、Dev Client は native bridge 用。',
    items: [
      { label: 'Expo mock screens', value: 'In progress', state: 'warning' },
      { label: 'Native bridge', value: 'Not started', state: 'off' },
      { label: 'Cutover', value: 'Feature flag later', state: 'off' },
    ],
  },
];

export const askMessages: AskMessage[] = [
  {
    id: 'm1',
    role: 'user',
    text: '今週の会議から、UI 移行で最初にやるべきことをまとめて',
  },
  {
    id: 'm2',
    role: 'assistant',
    text:
      '最初は Expo mock UI の足場作りです。Home、File Detail、Settings、Ask AI を実データなしで確認できる状態にし、STT と SwiftData は native bridge の境界が決まるまで触らない方針です。',
    sources: ['Growth 定例', 'React Native / Expo Migration Plan'],
  },
];
