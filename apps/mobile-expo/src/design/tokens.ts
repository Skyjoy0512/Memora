// ============================================================
// Memora Design Tokens — DESIGN.md §2-8
// 更新: 2026-07-14 / クリエイティブディレクション完了後
// 旧トークン: tokens.v6.ts
// ============================================================

import type { LayoutAnimationConfig } from 'react-native';

// ── Fonts ──────────────────────────────────────────────────
// Figma: IBM Plex Sans JP。本文は Regular、強調は Medium。
// fontFamily がウェイトを内包するため fontWeight は Android フォールバック用。
export const fonts = {
  sans: {
    extralight: { fontFamily: 'IBMPlexSansJP_200ExtraLight', fontWeight: '200' as const },
    light:      { fontFamily: 'IBMPlexSansJP_300Light',      fontWeight: '300' as const },
    regular:    { fontFamily: 'IBMPlexSansJP_400Regular',    fontWeight: '400' as const },
    medium:     { fontFamily: 'IBMPlexSansJP_500Medium',     fontWeight: '500' as const },
    semibold:   { fontFamily: 'IBMPlexSansJP_600SemiBold',   fontWeight: '600' as const },
  },
  // display も IBM Plex に統一（旧 M PLUS 1p は廃止）
  display: {
    extralight: { fontFamily: 'IBMPlexSansJP_200ExtraLight', fontWeight: '200' as const },
    light:      { fontFamily: 'IBMPlexSansJP_300Light',      fontWeight: '300' as const },
  },
  mono: {
    regular:  { fontFamily: 'Menlo', fontWeight: '400' as const },
    bold:     { fontFamily: 'Menlo', fontWeight: '700' as const },
  },
};

// ── Colors (Light) ─────────────────────────────────────────
export const colors = {
  canvas:         '#F3F3F1',
  surface:        '#FFFFFF',
  surfaceAlt:     '#EEEDEC',
  surfaceElevated:'#FFFFFF',

  text:           '#16171A',
  textSecondary:  '#6B6D70',
  textTertiary:   '#A0A2A5',
  textInverse:    '#FFFFFF',

  border:         '#DCDBD9',
  borderLight:    '#E7E6E4',
  separator:      '#E5E4E2',

  accent:         '#5B6B7A',
  accentSoft:     '#EEF0F2',
  accentMuted:    '#C4CAD1',

  success:        '#4F7A55',
  successSoft:    '#EDF2ED',
  warning:        '#8A6A3C',
  warningSoft:    '#F5EFE7',
  danger:         '#A34B45',
  dangerSoft:     '#F6ECEB',
  info:           '#46647D',
  infoSoft:       '#ECF0F3',

  recording:      '#A34B45',
  recordingSoft:  '#F6ECEB',

  skeleton:       '#E8E8E6',
  skeletonShimmer:'#F0F0EE',

  overlay:        'rgba(0,0,0,0.40)',
  overlayLight:   'rgba(0,0,0,0.20)',

  // Category（アプリアイコン由来・タグ/アバター用）
  categorySlate:  '#5B6B7A',
  categoryTeal:   '#4E7D78',
  categoryOlive:  '#6B7052',
  categoryMauve:  '#766A80',

} as const;

// ── Colors (Dark) ──────────────────────────────────────────
export const darkColors = {
  canvas:         '#0D0E0F',
  surface:        '#17181A',
  surfaceAlt:     '#212224',
  surfaceElevated:'#292A2D',

  text:           '#E9E9E8',
  textSecondary:  '#9C9D9F',
  textTertiary:   '#616264',
  textInverse:    '#16171A',

  border:         '#3A3B3E',
  borderLight:    '#303134',
  separator:      '#343538',

  accent:         '#9AA7B3',
  accentSoft:     '#23272B',
  accentMuted:    '#3D444B',

  success:        '#7FA187',
  successSoft:    '#1E2A20',
  warning:        '#B99A6C',
  warningSoft:    '#2B2620',
  danger:         '#C98884',
  dangerSoft:     '#2E2120',
  info:           '#7C9AB0',
  infoSoft:       '#1E262C',

  recording:      '#C98884',
  recordingSoft:  '#2E2120',

  skeleton:       '#23262A',
  skeletonShimmer:'#2A2D32',

  overlay:        'rgba(0,0,0,0.60)',
  overlayLight:   'rgba(0,0,0,0.35)',

  // Category（アプリアイコン由来・タグ/アバター用）
  categorySlate:  '#8A97A3',
  categoryTeal:   '#7FA69F',
  categoryOlive:  '#9AA07E',
  categoryMauve:  '#A99DB2',
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
// Figma「02 Components → Text styles」と 1:1 対応（サイズ/行間は Figma 実値）。
export const textStyles = {
  display: {
    fontSize: 36,
    lineHeight: 44,
    letterSpacing: typography.letterSpacing.tight,
    ...fonts.display.extralight,
  },
  screenTitle: {
    fontSize: 30,
    lineHeight: 38,
    letterSpacing: typography.letterSpacing.tight,
    ...fonts.sans.extralight,
  },
  title2: {
    fontSize: 24,
    lineHeight: 33,
    ...fonts.sans.light,
  },
  sectionTitle: {
    fontSize: 20,
    lineHeight: 28,
    ...fonts.sans.light,
  },
  callout: {
    fontSize: 17,
    lineHeight: 26,
    ...fonts.sans.regular,
  },
  body: {
    fontSize: 15,
    lineHeight: 24,
    ...fonts.sans.regular,
  },
  bodyBold: {
    fontSize: 15,
    lineHeight: 24,
    ...fonts.sans.medium,
  },
  footnote: {
    fontSize: 13,
    lineHeight: 20,
    ...fonts.sans.regular,
  },
  footnoteBold: {
    fontSize: 13,
    lineHeight: 20,
    ...fonts.sans.medium,
  },
  caption: {
    fontSize: 11,
    lineHeight: 16,
    letterSpacing: typography.letterSpacing.wide,
    ...fonts.sans.regular,
  },
  captionBold: {
    fontSize: 11,
    lineHeight: 16,
    letterSpacing: typography.letterSpacing.wide,
    ...fonts.sans.medium,
  },
  monoBody: {
    fontSize: 13,
    lineHeight: 20,
    ...fonts.mono.regular,
  },
};

// ── Shadows ────────────────────────────────────────────────
export const shadow = {
  card: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.07,
    shadowRadius: 8,
    elevation: 2,
  },
  elevated: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.12,
    shadowRadius: 18,
    elevation: 6,
  },
  floating: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.16,
    shadowRadius: 28,
    elevation: 10,
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
    pressDown: 100,
    reducedCrossfade: 120,
  },
  spring: {
    // Reanimated conversion: stiffness = mass × (2π / response)²;
    // damping = 2 × dampingRatio × √(stiffness × mass).
    // Critical damping (ratio 1.0), response 0.3s: immediate press recovery without overshoot.
    press: {
      damping: 42,
      mass: 1,
      stiffness: 439,
    },
    // Critical damping (ratio 1.0), response 0.4s: quiet list/content entrance and reordering.
    entrance: {
      damping: 31,
      mass: 1,
      stiffness: 247,
    },
    exit: {
      damping: 42,
      mass: 1,
      stiffness: 439,
    },
    reorder: {
      damping: 31,
      mass: 1,
      stiffness: 247,
    },
    // Damping ratio 0.8, response 0.3s: reserved for momentum-driven drawers and sheets.
    sheet: {
      damping: 34,
      mass: 1,
      stiffness: 439,
    },
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
