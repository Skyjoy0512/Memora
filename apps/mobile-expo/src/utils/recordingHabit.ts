/**
 * 直近 N 日の「記録した日」を並べる（Open Design v2 の設定「記録の習慣」）。
 *
 * 返す配列は古い日 → 今日の順。表示は 7 列 × 4 行のグリッドなので、
 * 既定の 28 日はちょうど 4 週間ぶんになる。
 */
export type RecordingHabit = {
  /** 古い日から今日までの、記録があったかどうか。長さは days。 */
  days: boolean[];
  /** days のうち true の数。 */
  recordedCount: number;
  /** 参照した日数（days.length と同じ）。 */
  totalDays: number;
};

const DAY_MS = 86_400_000;

/** ローカル時刻でのその日の 0 時。タイムゾーンをまたいでも「日」で数える。 */
function startOfDay(date: Date): number {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

export function buildRecordingHabit(
  recordedAtValues: readonly string[],
  now: Date = new Date(),
  days = 28,
): RecordingHabit {
  const totalDays = Math.max(0, Math.floor(days));
  const today = startOfDay(now);
  const oldest = today - (totalDays - 1) * DAY_MS;

  const recorded = new Set<number>();
  for (const value of recordedAtValues) {
    const timestamp = Date.parse(value);
    if (Number.isNaN(timestamp)) continue;
    const day = startOfDay(new Date(timestamp));
    if (day >= oldest && day <= today) recorded.add(day);
  }

  const result: boolean[] = [];
  for (let index = 0; index < totalDays; index += 1) {
    result.push(recorded.has(oldest + index * DAY_MS));
  }

  return {
    days: result,
    recordedCount: result.filter(Boolean).length,
    totalDays,
  };
}
