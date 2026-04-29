import SwiftUI
import UIKit

// MARK: - Adaptive Color Helper

/// Light/Dark モードに自動適応する Color を生成する。
/// iOS 17+ の `UIColor { traitCollection }` パターンを利用。
private func adaptiveColor(light: String, dark: String) -> Color {
    Color(uiColor: UIColor { traitCollection in
        let hex = traitCollection.userInterfaceStyle == .dark ? dark : light
        return UIColor(hexString: hex)
    })
}

/// オパシティ付きの Adaptive Color。
private func adaptiveColor(
    light: String, lightAlpha: Double,
    dark: String, darkAlpha: Double
) -> Color {
    Color(uiColor: UIColor { traitCollection in
        let isDark = traitCollection.userInterfaceStyle == .dark
        let hex = isDark ? dark : light
        let alpha = isDark ? darkAlpha : lightAlpha
        return UIColor(hexString: hex).withAlphaComponent(alpha)
    })
}

/// シングルカラー + オパシティの Adaptive Color。
private func adaptiveAlpha(_ base: String, light: Double, dark: Double) -> Color {
    Color(uiColor: UIColor { traitCollection in
        let alpha = traitCollection.userInterfaceStyle == .dark ? dark : light
        return UIColor(hexString: base).withAlphaComponent(alpha)
    })
}

// MARK: - UIColor Hex Extension

private extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64, r: UInt64, g: UInt64, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Color Hex Extension（後方互換）

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Memora Color Tokens（ChatGPT Design System — Light/Dark Adaptive）

enum MemoraColor {
    // ── Backgrounds ──────────────────────────────────────────
    static let surfacePrimary   = adaptiveColor(light: "FFFFFF", dark: "1C1C1E")
    static let surfaceSecondary = adaptiveColor(light: "F5F5F5", dark: "2C2C2E")
    static let surfaceElevated  = adaptiveColor(light: "FFFFFF", dark: "3A3A3C")
    static let surfaceGlass     = adaptiveAlpha("FFFFFF", light: 0.48, dark: 0.12)
    static let surfaceCard      = adaptiveColor(light: "FFFFFF", dark: "1C1C1E")
    static let surfaceInput     = adaptiveColor(light: "F3F3F3", dark: "2C2C2E")

    // ── Text ─────────────────────────────────────────────────
    static let textPrimary   = adaptiveColor(light: "0D0D0D", dark: "F5F5F7")
    static let textSecondary = adaptiveColor(light: "6E6E80", dark: "98989D")
    static let textTertiary  = adaptiveColor(light: "8E8EA0", dark: "636366")

    // ── Accents ──────────────────────────────────────────────
    static let accentPrimary = adaptiveColor(light: "0D0D0D", dark: "F5F5F7")
    static let accentBlue    = adaptiveColor(light: "007AFF", dark: "0A84FF")
    static let accentRed     = adaptiveColor(light: "E02E2A", dark: "FF453A")
    static let accentGreen   = adaptiveColor(light: "34C759", dark: "30D158")

    // ── Dividers ─────────────────────────────────────────────
    static let divider = adaptiveColor(light: "E5E5EA", dark: "38383A")

    // ── Interactive (ChatGPT-aligned) ────────────────────────
    static let interactivePrimary        = adaptiveColor(light: "0D0D0D", dark: "F5F5F7")
    static let interactivePrimaryLabel   = adaptiveColor(light: "FFFFFF", dark: "0D0D0D")
    static let interactiveSecondaryBorder = adaptiveAlpha("0D0D0D", light: 0.10, dark: 0.10)
    static let interactiveHoverBg        = adaptiveAlpha("0D0D0D", light: 0.02, dark: 0.03)
    static let interactivePressBg        = adaptiveAlpha("0D0D0D", light: 0.05, dark: 0.05)
    static let interactiveHoverBorder    = adaptiveAlpha("0D0D0D", light: 0.05, dark: 0.06)

    // ── Segmented Control (ChatGPT-aligned) ──────────────────
    static let segmentBg       = adaptiveColor(light: "E8E8E8", dark: "3A3A3C")
    static let segmentSelected = adaptiveColor(light: "FFFFFF", dark: "4A4A4C")

    // ── Monochrome Accent (legacy compat) ────────────────────
    static let accentNothing       = interactivePrimary
    static let accentNothingGlow   = adaptiveAlpha("0D0D0D", light: 0.06, dark: 0.04)
    static let accentNothingSubtle = adaptiveAlpha("0D0D0D", light: 0.04, dark: 0.04)

    // ── Glass ────────────────────────────────────────────────
    static let glassBorder    = adaptiveAlpha("FFFFFF", light: 0.18, dark: 0.10)
    static let glassHighlight = adaptiveAlpha("FFFFFF", light: 0.25, dark: 0.08)
    static let glassShadow    = adaptiveAlpha("000000", light: 0.06, dark: 0.20)
    static let glassTint      = adaptiveAlpha("0D0D0D", light: 0.02, dark: 0.04)

    // ── Dot Matrix ───────────────────────────────────────────
    static let dotMatrixPrimary = adaptiveAlpha("0D0D0D", light: 0.06, dark: 0.06)
    static let dotMatrixAccent  = adaptiveColor(
        light: "007AFF", lightAlpha: 0.12,
        dark: "0A84FF", darkAlpha: 0.15
    )

    // ── Shadows ──────────────────────────────────────────────
    static let shadowLight     = adaptiveAlpha("000000", light: 0.04, dark: 0.20)
    static let shadowMedium    = adaptiveAlpha("000000", light: 0.08, dark: 0.30)
    static let shadowSegment   = adaptiveAlpha("000000", light: 0.06, dark: 0.25)

    // ── Skeleton ─────────────────────────────────────────────
    static let skeletonShimmer = adaptiveColor(light: "E8E8EA", dark: "3A3A3C")
}
