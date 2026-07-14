import SwiftUI

// MARK: - V6 Design Tokens
// Source of truth: design_handoff_memora_v6/「Memora Redesign v6.dc.html」(canonical) + README「Design Tokens」。
// 数値は HTML のインライン CSS / JS ステートマシンから実測。直値散布禁止 — 画面実装は必ずこのトークン経由で使う。
// 参照 PNG: docs/design/screens/**（ピクセル照合の正）。

enum V6Color {
    // Ink / text
    static let ink = Color(hex: "0D0D0D")        // primary text / fill
    static let secondary = Color(hex: "3A3A3C")  // secondary text
    static let tertiary = Color(hex: "6E6E80")   // muted text
    static let muted = Color(hex: "8E8EA0")      // tertiary / caption text
    static let quiet = Color(hex: "B2B2B2")      // disabled-ish label

    // Surfaces
    static let white = Color.white               // phone screen bg
    static let canvas = Color(hex: "ECECEC")     // app canvas bg
    static let faint = Color(hex: "F7F7F7")      // light fill (filter rows)
    static let soft = Color(hex: "F5F5F5")       // light fill (fields / chips)
    static let fillStrong = Color(hex: "F3F3F3") // secondary button fill
    static let paleLine = Color(hex: "F2F2F2")

    // Lines / borders
    static let line = Color(hex: "E5E5EA")         // hairline / divider
    static let neutralBorder = Color(hex: "C7C7CC") // wireframe / disabled border
    static let cardBorderInactive = Color(hex: "F0F0F0") // unselected plan card border

    // Accents
    static let accent = Color(hex: "FF3030")        // record / live state
    static let accentPressed = Color(hex: "E02020") // record pressed
    static let danger = Color(hex: "FF3030")
    static let success = Color(hex: "34C759")

    // Dynamic Island surface (in-app pill)
    static let islandSurface = Color(hex: "0D0D0D")
}

enum V6Font {
    // Screen titles
    static let title = Font.system(size: 32, weight: .bold)       // Home「全ファイル」(32/700, tracking -0.02em)
    static let screenTitle = Font.system(size: 30, weight: .bold) // Tasks / Ask / Settings (30/700, -0.02em)
    static let appTitle = Font.system(size: 34, weight: .bold)    // Login「Memora」(34/700, -0.02em)
    static let proTitle = Font.system(size: 26, weight: .bold)    // Paywall「Memora Pro」(26/700, -0.01em)
    static let fileTitle = Font.system(size: 24, weight: .bold)   // File Detail file name (24/700, -0.01em)
    static let authTitle = Font.system(size: 22, weight: .bold)   // Login sub-step headings (22/700)

    // Recording elapsed time (monospaced)
    static let recTime = Font.system(size: 44, weight: .semibold, design: .monospaced) // (44/600, -0.01em)

    // Labels / body
    static let eyebrow = Font.system(size: 12, weight: .semibold) // uppercase, tracking .04em (applied in view)
    static let section = Font.system(size: 12, weight: .medium)   // section labels
    static let rowTitle = Font.system(size: 15, weight: .medium)  // list row title
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyLarge = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)
    static let button = Font.system(size: 16, weight: .semibold)  // primary CTA
    static let buttonSmall = Font.system(size: 15, weight: .semibold) // provider buttons
    static let caption = Font.system(size: 11, weight: .regular)
}

/// Letter-spacing helpers (pt = fontSize * em). HTML: title -0.02em, proTitle/fileTitle -0.01em.
enum V6Tracking {
    static let title: CGFloat = -0.64      // 32 * -0.02
    static let screenTitle: CGFloat = -0.60 // 30 * -0.02
    static let appTitle: CGFloat = -0.68   // 34 * -0.02
    static let proTitle: CGFloat = -0.26   // 26 * -0.01
    static let fileTitle: CGFloat = -0.24  // 24 * -0.01
    static let eyebrow: CGFloat = 0.48     // 12 * .04em, uppercase
}

/// Corner radii (px == pt). HTML radius scale.
enum V6Radius {
    static let chip: CGFloat = 6        // small chips / meta pills
    static let field: CGFloat = 12      // inputs / list fill rows / small cards
    static let providerButton: CGFloat = 14 // Apple/Google/email stack
    static let card: CGFloat = 14
    static let cardAlt: CGFloat = 16    // large cards / primary CTA
    static let cta: CGFloat = 16        // filled primary CTA
    static let pill: CGFloat = 24       // pills / FAB / tab bar
}

/// Soft, low-opacity shadows only (no glow / glass).
enum V6Shadow {
    /// `0 1px 6px rgba(0,0,0,.04)` — cards / rows.
    static func card(_ view: some View) -> some View {
        view.shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }
    /// `0 8px 24px rgba(0,0,0,.28)` — Dynamic Island pill (active).
    static func island(_ view: some View) -> some View {
        view.shadow(color: .black.opacity(0.28), radius: 12, y: 8)
    }
    /// `0 12px 32px rgba(0,0,0,.32)` — floating bottom tab bar.
    static func tabBar(_ view: some View) -> some View {
        view.shadow(color: .black.opacity(0.32), radius: 16, y: 12)
    }
    /// `0 30px 70px rgba(0,0,0,.22)` — bottom sheets.
    static func sheet(_ view: some View) -> some View {
        view.shadow(color: .black.opacity(0.22), radius: 35, y: 30)
    }
}

/// Animation curves matching the prototype keyframes (respect `accessibilityReduceMotion` at call sites).
enum V6Anim {
    /// Dynamic Island morph — cubic-bezier(.32,.72,0,1), .42s.
    static let islandMorph = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.42)
    /// Bottom sheet slide-in (translateY 100%→0).
    static let sheetUp = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.42)
    /// Card / popover (scale .94→1 + fade).
    static let popIn = Animation.easeOut(duration: 0.22)
    /// Toast / snackbar slide + fade.
    static let toastIn = Animation.easeOut(duration: 0.25)
    /// Generic fade-in (translateY 6px→0).
    static let fadeIn = Animation.easeOut(duration: 0.2)
}

/// Dynamic Island pill dimensions per mode (in-app reproduction). Source: JS `islandDimsByMode`.
enum V6IslandDims {
    /// (width, height, cornerRadius)
    static let idle: (CGFloat, CGFloat, CGFloat) = (120, 35, 20)
    static let snackbar: (CGFloat, CGFloat, CGFloat) = (304, 54, 27)
    static let liveRec: (CGFloat, CGFloat, CGFloat) = (156, 36, 18)
    static let liveGen: (CGFloat, CGFloat, CGFloat) = (198, 36, 18)
    static let ask: (CGFloat, CGFloat, CGFloat) = (280, 68, 34)
    static let askAnswer: (CGFloat, CGFloat, CGFloat) = (320, 210, 26)
    static let askMorph: (CGFloat, CGFloat, CGFloat) = (362, 700, 40)
}

// MARK: - Shared controls

struct V6PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(V6Font.button)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isEnabled ? V6Color.ink : V6Color.neutralBorder)
                .clipShape(RoundedRectangle(cornerRadius: V6Radius.cta, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct V6IconBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(V6Color.ink)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }
}

struct V6DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(V6Color.neutralBorder)
    }
}
