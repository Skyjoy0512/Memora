export function formatRecordedAt(value: string, now = new Date()): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  const time = new Intl.DateTimeFormat('ja-JP', { hour: '2-digit', minute: '2-digit', hour12: false }).format(date);
  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startYesterday = new Date(startToday); startYesterday.setDate(startYesterday.getDate() - 1);
  if (date >= startToday) return `今日 ${time}`;
  if (date >= startYesterday) return `昨日 ${time}`;
  const monthDay = `${date.getMonth() + 1}月${date.getDate()}日 ${time}`;
  return date.getFullYear() === now.getFullYear() ? monthDay : `${date.getFullYear()}年${monthDay}`;
}
