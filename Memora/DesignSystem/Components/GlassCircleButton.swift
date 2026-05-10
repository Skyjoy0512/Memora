import SwiftUI

/// Liquid Glass の円形ボタン。外側に Liquid Glass の円、内側に色付き円を重ねた二重構造。
///
/// 使用例:
/// ```swift
/// GlassCircleButton(icon: "textformat.size", diameter: 56) {
///     // font size action
/// }
///
/// GlassCircleButton(icon: "chevron.left", diameter: 56) {
///     // go back
/// }
///
/// GlassCircleButton(icon: "ellipsis", diameter: 44, innerColor: .gray.opacity(0.3)) {
///     // more options
/// }
/// ```
///
/// - 外円直径 `diameter`（デフォルト 56pt）、内円直径 `diameter * 0.78`（最小タップ領域 44pt を保証）。
/// - iOS 26: 外円に `glassEffect(.regular.interactive(), in: .circle)`
/// - iOS 17-25: `.ultraThinMaterial` Circle + 白 overlay + 0.5pt 白 stroke + shadow
struct GlassCircleButton: View {
    let icon: String
    var diameter: CGFloat
    var innerColor: Color
    var iconColor: Color
    let action: () -> Void

    /// 内円の直径。最小 44pt を保証。
    private var innerDiameter: CGFloat {
        max(diameter * 0.78, MemoraSize.minTapTarget)
    }

    init(
        icon: String,
        diameter: CGFloat = 56,
        innerColor: Color = MemoraColor.circleButtonInner,
        iconColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.diameter = diameter
        self.innerColor = innerColor
        self.iconColor = iconColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glass circle
                Circle()
                    .fill(.clear)
                    .frame(width: diameter, height: diameter)
                    .liquidGlassCircle()

                // Inner colored circle
                Circle()
                    .fill(innerColor)
                    .frame(width: innerDiameter, height: innerDiameter)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: innerDiameter * 0.4, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("円形ボタン")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack(spacing: 20) {
        GlassCircleButton(icon: "textformat.size", diameter: 56) {}
        GlassCircleButton(icon: "chevron.left", diameter: 56) {}
        GlassCircleButton(icon: "ellipsis", diameter: 44,
                          innerColor: MemoraColor.surfacePill,
                          iconColor: MemoraColor.textPrimary) {}
    }
    .padding()
    .background(MemoraColor.surfaceBackground)
}
#endif
