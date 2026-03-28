import SwiftUI

struct PillButton: View {
    let title: String
    let action: () -> Void
    var style: Style = .primary

    enum Style {
        case primary
        case outline
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MemoraTypography.headline)
                .foregroundStyle(style == .primary ? .white : MemoraColor.accentPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    style == .primary
                        ? MemoraColor.accentPrimary
                        : Color.clear
                )
                .overlay(
                    Capsule()
                        .stroke(style == .primary ? Color.clear : MemoraColor.accentPrimary, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }
}
