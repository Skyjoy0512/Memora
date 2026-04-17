import SwiftUI

// MARK: - Ask AI Compact Bar

struct AskAICompactBar: View {
    let provider: AIProvider
    let showAskAI: Binding<Bool>

    var body: some View {
        Button {
            showAskAI.wrappedValue = true
        } label: {
            HStack(spacing: MemoraSpacing.sm) {
                Text(provider.rawValue)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentNothing)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 2)
                    .background(MemoraColor.accentNothingSubtle)
                    .clipShape(Capsule())

                Text("Ask AI...")
                    .font(MemoraTypography.body)
                    .foregroundStyle(.tertiary)

                Spacer()

                Image(systemName: "sparkle")
                    .foregroundStyle(MemoraColor.accentNothing)
                    .nothingGlow(.subtle)
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .glassCard(.init(cornerRadius: 24, glow: false))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.sm)
    }
}
