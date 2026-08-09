export type TaskDue = '期限切れ' | '今日' | '今後';

export function classifyTaskDue(
  dueDate: string | null | undefined,
  now: Date = new Date(),
): TaskDue {
  if (!dueDate) return '今後';
  const due = new Date(dueDate);
  if (Number.isNaN(due.getTime())) return '今後';

  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const startOfDueDay = new Date(due.getFullYear(), due.getMonth(), due.getDate()).getTime();

  if (startOfDueDay < startOfToday) return '期限切れ';
  if (startOfDueDay === startOfToday) return '今日';
  return '今後';
}

export function taskDueDateForChoice(
  choice: '今日' | '明日' | '日付を選択',
  now: Date = new Date(),
): string | undefined {
  if (choice === '日付を選択') return undefined;
  const date = new Date(now);
  if (choice === '明日') {
    date.setDate(date.getDate() + 1);
  }
  return date.toISOString();
}
