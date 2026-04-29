import SwiftUI

/// ChatGPT Design System — Button
/// Pill-shaped button with primary / secondary / destructive variants.
/// Large (h44, 14pt) and Compact (h36, 13pt) sizes.
struct PillButton: View {
    let title: String
    let action: () -> Void
    var style: Style = .primary
    var size: Size = .regular
    var isDisabled: Bool = false

    enum Style {
        case primary
        case secondary
        case destructive
        case destructiveSecondary
        case glass
    }

    enum Size {
        case regular    // h44, font 14pt Medium
        case compact    // h36, font 13pt Medium
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(size == .regular ? MemoraTypography.chatButton : MemoraTypography.chatButtonSmall)
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity)
                .frame(height: size == .regular ? 44 : 36)
                .background(backgroundColor)
                .overlay {
                    Capsule()
                        .stroke(borderColor, lineWidth: 1)
                }
                .clipShape(Capsule())
        }
        .opacity(isDisabled ? disabledOpacity : 1)
        .disabled(isDisabled)
    }

    // MARK: - Colors (ChatGPT specs)

    private var labelColor: Color {
        switch style {
        case .primary:
            return MemoraColor.interactivePrimaryLabel
        case .secondary:
            return MemoraColor.textPrimary
        case .destructive:
            return .white
        case .destructiveSecondary:
            return MemoraColor.accentRed
        case .glass:
            return MemoraColor.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return MemoraColor.interactivePrimary
        case .secondary:
            return Color.clear
        case .destructive:
            return MemoraColor.accentRed
        case .destructiveSecondary:
            return Color.clear
        case .glass:
            return Color.clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return MemoraColor.interactiveSecondaryBorder
        case .destructive:
            return Color.clear
        case .destructiveSecondary:
            return MemoraColor.accentRed
        case .glass:
            return Color.clear
        }
    }

    private var disabledOpacity: Double {
        switch style {
        case .primary, .destructive, .destructiveSecondary:
            return 0.40
        case .secondary, .glass:
            return 0.70
        }
    }
}
