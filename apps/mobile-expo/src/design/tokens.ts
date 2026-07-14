// ============================================================
// Memora Design Tokens — DESIGN.md §2-8
// 更新: 2026-07-14 / クリエイティブディレクション完了後
// 旧トークン: tokens.v6.ts
// ============================================================

import type { LayoutAnimationConfig } from 'react-native';

// ── Fonts ──────────────────────────────────────────────────
export const fonts = {
  sans: {
    regular:  { fontFamily: 'NotoSansJP_400Regular', fontWeight: '400' as const },
    medium:   { fontFamily: 'NotoSansJP_500Medium',  fontWeight: '500' as const },
    bold:     { fontFamily: 'NotoSansJP_700Bold',     fontWeight: '700' as const },
  },
  display: {
    regular:  { fontFamily: 'MPLUS1p_400Regular', fontWeight: '400' as const },
    medium:   { fontFamily: 'MPLUS1p_500Medium',  fontWeight: '500' as const },
    bold:     { fontFamily: 'MPLUS1p_700Bold',     fontWeight: '700' as const },
  },
  mono: {
    regular:  { fontFamily: 'Menlo', fontWeight: '400' as const },
    bold:     { fontFamily: 'Menlo', fontWeight: '700' as const },
  },
};

// ── Colors (Light) ─────────────────────────────────────────
export const colors = {
  canvas:         '#FAFAF8',
  surface:        '#FFFFFF',
  surfaceAlt:     '#F3F3F2',
  surfaceElevated:'#FFFFFF',

  text:           '#1A1C1E',
  textSecondary:  '#5F6368',
  textTertiary:   '#9AA0A6',
  textInverse:    '#FFFFFF',

  border:         '#E2E3E5',
  borderLight:    '#EEEEEF',
  separator:      '#F0F0F0',

  accent:         '#1A7F6B',
  accentSoft:     '#E8F5F1',
  accentMuted:    '#B8D8CF',

  success:        '#2E7D32',
  successSoft:    '#E8F5E9',
  warning:        '#E65100',
  warningSoft:    '#FFF3E0',
  danger:         '#C62828',
  dangerSoft:     '#FFEBEE',
  info:           '#1565C0',
  infoSoft:       '#E3F2FD',

  recording:      '#C62828',
  recordingSoft:  '#FFEBEE',

  skeleton:       '#E8E8E6',
  skeletonShimmer:'#F0F0EE',

  overlay:        'rgba(0,0,0,0.40)',
  overlayLight:   'rgba(0,0,0,0.20)',

} as const;

// ── Colors (Dark) ──────────────────────────────────────────
export const darkColors = {
  canvas:         '#0F1114',
  surface:        '#1A1D21',
  surfaceAlt:     '#23262A',
  surfaceElevated:'#2A2D32',

  text:           '#E8EAED',
  textSecondary:  '#9AA0A6',
  textTertiary:   '#5F6368',
  textInverse:    '#1A1C1E',

  border:         '#3C4043',
  borderLight:    '#313437',
  separator:      '#2A2D32',

  accent:         '#3DD9B0',
  accentSoft:     '#1A332E',
  accentMuted:    '#2A5C52',

  success:        '#4CAF50',
  successSoft:    '#1B3320',
  warning:        '#FF9800',
  warningSoft:    '#332A1A',
  danger:         '#EF5350',
  dangerSoft:     '#331A1D',
  info:           '#42A5F5',
  infoSoft:       '#1A2533',

  recording:      '#EF5350',
  recordingSoft:  '#331A1D',

  skeleton:       '#23262A',
  skeletonShimmer:'#2A2D32',

  overlay:        'rgba(0,0,0,0.60)',
  overlayLight:   'rgba(0,0,0,0.35)',
} as const;

// ── Spacing (golden ratio) ─────────────────────────────────
export const spacing = {
  xxs:  3,
  xs:   5,
  sm:   8,
  md:   13,
  lg:   21,
  xl:   34,
  xxl:  55,
} as const;

export const screenPadding = {
  horizontal: spacing.lg,
} as const;

// ── Radius ─────────────────────────────────────────────────
export const radius = {
  xs:    4,
  sm:    8,
  md:   13,
  lg:   21,
  pill:  999,
} as const;

// ── Typography ─────────────────────────────────────────────
export const typography = {
  size: {
    caption:   11,
    footnote:  13,
    body:      15,
    callout:   17,
    title3:    20,
    title2:    24,
    title1:    30,
    headline:  36,
  },
  lineHeight: (fontSize: number, ratio: number = 1.6) =>
    Math.round(fontSize * ratio),
  letterSpacing: {
    tight:  -0.4,
    normal:  0,
    wide:    0.3,
  },
} as const;

// ── Text style presets ─────────────────────────────────────
export const textStyles = {
  screenTitle: {
    fontSize: typography.size.title1,
    lineHeight: typography.lineHeight(30, 1.3),
    letterSpacing: typography.letterSpacing.tight,
    ...fonts.sans.bold,
  },
  sectionTitle: {
    fontSize: typography.size.title3,
    lineHeight: typography.lineHeight(20, 1.4),
    ...fonts.sans.bold,
  },
  body: {
    fontSize: typography.size.body,
    lineHeight: typography.lineHeight(15, 1.6),
    ...fonts.sans.regular,
  },
  bodyBold: {
    fontSize: typography.size.body,
    lineHeight: typography.lineHeight(15, 1.6),
    ...fonts.sans.bold,
  },
  caption: {
    fontSize: typography.size.caption,
    lineHeight: typography.lineHeight(11, 1.4),
    letterSpacing: typography.letterSpacing.wide,
    ...fonts.sans.regular,
  },
  monoBody: {
    fontSize: 13,
    lineHeight: typography.lineHeight(13, 1.5),
    ...fonts.mono.regular,
  },
  display: {
    fontSize: typography.size.headline,
    lineHeight: typography.lineHeight(36, 1.15),
    letterSpacing: typography.letterSpacing.tight,
    ...fonts.display.bold,
  },
};

// ── Shadows ────────────────────────────────────────────────
export const shadow = {
  card: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  elevated: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.10,
    shadowRadius: 16,
    elevation: 4,
  },
  floating: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.14,
    shadowRadius: 24,
    elevation: 8,
  },
} as const;

// ── Icons ──────────────────────────────────────────────────
export const iconSize = {
  sm: 16,
  md: 20,
  lg: 24,
  xl: 28,
} as const;

// ── Motion presets ─────────────────────────────────────────
export const motion = {
  duration: {
    fast:   150,
    normal: 200,
    slow:   350,
  },
  spring: {
    tap: {
      damping: 15,
      stiffness: 300,
      mass: 0.5,
    },
  },
  layout: {
    easeInEaseOut: { duration: 300, create: { type: 'easeInEaseOut', property: 'opacity' }, update: { type: 'easeInEaseOut' }, delete: { type: 'easeInEaseOut', property: 'opacity' } } as LayoutAnimationConfig,
  },
} as const;
