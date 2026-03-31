import SwiftUI

struct ToastOverlay: View {
    let icon: String
    let message: String
    var style: Style = .error
    var dismissDuration: TimeInterval = 4.0
    var onDismiss: (() -> Void)? = nil

    @State private var isVisible = false

    enum Style {
        case error
        case success
        case info

        var iconColor: Color {
            switch self {
            case .error: return MemoraColor.accentRed
            case .success: return MemoraColor.accentGreen
            case .info: return MemoraColor.accentBlue
            }
        }

        var tintColor: Color {
            switch self {
            case .error: return MemoraColor.accentRed.opacity(0.15)
            case .success: return MemoraColor.accentGreen.opacity(0.15)
            case .info: return MemoraColor.accentBlue.opacity(0.15)
            }
        }
    }

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            Image(systemName: icon)
                .font(MemoraTypography.body)
                .foregroundStyle(style.iconColor)

            Text(message)
                .font(MemoraTypography.subheadline)
                .foregroundStyle(MemoraColor.textPrimary)
                .lineLimit(2)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.textTertiary)
            }
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.sm)
        .liquidGlass(cornerRadius: MemoraRadius.md)
        .padding(.horizontal, MemoraSpacing.md)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
            scheduleAutoDismiss()
        }
    }

    private func scheduleAutoDismiss() {
        guard dismissDuration > 0 else { return }
        Task {
            try? await Task.sleep(for: .seconds(dismissDuration))
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss?()
        }
    }
}
