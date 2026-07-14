export const colors = {
  canvas: '#FFFFFF',
  surface: '#FFFFFF',
  surfaceAlt: '#F3F3F3',
  faint: '#F7F7F7',
  text: '#0D0D0D',
  textMuted: '#3A3A3C',
  textSubtle: '#6E6E80',
  textMutedLight: '#8E8EA0',
  quiet: '#B2B2B2',
  border: '#E5E5EA',
  neutralBorder: '#C7C7CC',
  soft: '#F5F5F5',
  paleLine: '#F2F2F2',
  accent: '#FF3030',
  accentSoft: '#FFF0F0',
  warning: '#A65F00',
  warningSoft: '#FFF0D1',
  danger: '#FF3030',
  dangerSoft: '#FFF0F0',
  success: '#34C759',
  successSoft: '#ECF9EF',
  ink: '#0D0D0D',
} as const;

// Golden-ratio spacing scale (phi = 1.618). See CLAUDE.md §6.3.
export const spacing = {
  xs: 5,
  sm: 8,
  md: 13,
  lg: 21,
  xl: 34,
  xxl: 55,
} as const;

// Golden-ratio corner radius scale: 8 / 13 / 21. `pill` stays a full-round sentinel.
export const radius = {
  chip: 8,
  sm: 8,
  md: 13,
  cardAlt: 21,
  lg: 21,
  pill: 999,
} as const;

// Golden-ratio type scale. Line height target: fontSize * 1.45–1.62.
export const typography = {
  size: { caption: 12, body: 14, subtitle: 17, title: 21, headline: 26, display: 34 },
  lineHeight: (fontSize: number, ratio: number = 1.5) => Math.round(fontSize * ratio),
} as const;

export const shadow = {
  card: { boxShadow: '0px 1px 6px rgba(0, 0, 0, 0.04)', elevation: 1 },
} as const;
