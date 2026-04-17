import SwiftUI

struct PillButton: View {
    let title: String
    let action: () -> Void
    var style: Style = .primary

    enum Style {
        case primary
        case outline
        case glass
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MemoraTypography.headline)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(background)
                .overlay {
                    Capsule()
                        .stroke(strokeColor, lineWidth: 1)
                }
                .clipShape(Capsule())
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .outline: return MemoraColor.accentPrimary
        case .glass: return MemoraColor.textPrimary
        }
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:
                MemoraColor.accentPrimary
            case .outline:
                Color.clear
            case .glass:
                Color.clear
            }
        }
    }

    private var strokeColor: Color {
        switch style {
        case .primary: return Color.clear
        case .outline: return MemoraColor.accentNothing
        case .glass: return Color.clear
        }
    }
}
