const statusLabels: Record<string, string> = {
  ready: '文字起こし済み',
  transcribing: '文字起こし中',
  processing: '文字起こし中',
  queued: '文字起こし待ち',
  summarized: '要約済み',
  completed: '文字起こし済み',
  failed: '確認が必要',
};

const fallbackLabel = '処理待ち';

export function formatStatus(status: string | undefined | null): string {
  const normalized = status?.trim().toLowerCase() ?? '';
  return statusLabels[normalized] ?? fallbackLabel;
}
