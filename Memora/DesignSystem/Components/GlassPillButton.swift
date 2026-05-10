import SwiftUI

/// Liquid Glass のピル型ボタン。
///
/// 使用例:
/// ```swift
/// GlassPillButton(label: "PLAUD Note Pro", height: 43) {
///     // navigate to device detail
/// }
///
/// GlassPillButton(label: "録音開始", icon: "waveform", height: 80) {
///     // start recording
/// }
/// ```
///
/// - iOS 26: `glassEffect(.regular.interactive(), in: .rect(cornerRadius: height/2))`
/// - iOS 17-25: `.ultraThinMaterial` + 白 overlay + 0.5pt 白 stroke + shadow
struct GlassPillButton: View {
    let label: String
    let icon: String?
    var height: CGFloat
    var font: Font
    let action: () -> Void

    init(
        label: String,
        icon: String? = nil,
        height: CGFloat = 43,
        font: Font = MemoraTypography.chatButton,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.height = height
        self.font = font
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MemoraSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(font)
                        .foregroundStyle(MemoraColor.textPrimary)
                }
                Text(label)
                    .font(font)
                    .foregroundStyle(MemoraColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, height * 0.6)
            .frame(height: height)
            .contentShape(.rect(cornerRadius: height / 2))
            .liquidGlass(cornerRadius: height / 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        GlassPillButton(label: "PLAUD Note Pro", height: 43) {}
        GlassPillButton(label: "録音開始", icon: "waveform", height: 56) {}
        GlassPillButton(label: "インポート", icon: "square.and.arrow.down", height: 56) {}
    }
    .padding()
    .background(MemoraColor.surfaceBackground)
}
#endif
