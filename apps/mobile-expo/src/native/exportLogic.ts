import type { ExportDestination, ExportPayloadDTO } from './MemoraNative.types';
import type { AudioFile } from '../types/memora';

// ── Markdown ────────────────────────────────────────────
const SUMMARY_HEADING = '## 要約';
const TRANSCRIPT_HEADING = '## 文字起こし';

/**
 * summary（Markdown）と transcript（`time text` 行並び）を結合した書き出し用 Markdown を組み立てる。
 * 見出し区切りは native（MemoraRNExportHandlers.makeBlocks）と共有する決め事。
 */
export function buildExportMarkdown(
  summary: string,
  transcript: Array<{ time: string; text: string }>,
): string {
  const sections: string[] = [];
  const trimmedSummary = summary.trim();
  if (trimmedSummary) {
    sections.push(`${SUMMARY_HEADING}\n\n${trimmedSummary}`);
  }
  const transcriptText = transcript
    .map((segment) => `${segment.time} ${segment.text}`)
    .join('\n')
    .trim();
  if (transcriptText) {
    sections.push(`${TRANSCRIPT_HEADING}\n\n${transcriptText}`);
  }
  return sections.join('\n\n');
}

// ── Payload ─────────────────────────────────────────────
export function buildExportPayload(
  file: Pick<AudioFile, 'id' | 'title' | 'summary' | 'transcript'>,
  destination: ExportDestination,
): ExportPayloadDTO {
  return {
    title: file.title,
    text: buildExportMarkdown(file.summary, file.transcript),
    createdAt: new Date().toISOString(),
    sourceFileId: file.id,
    destination,
  };
}

// ── Notion 親ページ ─────────────────────────────────────
/** 親ページURLから32文字hexのページIDを抽出する（URL でなければそのまま ID として扱う）。 */
export function extractNotionParentPageId(input: string): string | null {
  const match = input.match(/[0-9a-f]{32}/i);
  return match ? match[0].toLowerCase() : null;
}

export type NotionSetupState = 'ready' | 'token-missing' | 'parent-missing' | 'not-configured';

export function resolveNotionSetupState(
  tokenConfigured: boolean,
  parentPageConfigured: boolean,
): NotionSetupState {
  if (!tokenConfigured) {
    return 'not-configured';
  }
  if (!parentPageConfigured) {
    return 'parent-missing';
  }
  return 'ready';
}

export const NOTION_SETUP_LABELS: Record<NotionSetupState, string> = {
  ready: '設定済み',
  'token-missing': 'トークン未設定',
  'parent-missing': '親ページ未設定',
  'not-configured': '未設定',
};
