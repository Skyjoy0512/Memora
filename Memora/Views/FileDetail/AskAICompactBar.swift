import SwiftUI

// MARK: - Ask AI Compact Bar (inline text field)

struct AskAICompactBar: View {
    let provider: AIProvider
    let showAskAI: Binding<Bool>
    var onSend: ((String) -> Void)? = nil
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(MemoraColor.divider)
                .frame(height: 0.5)

            HStack(spacing: MemoraSpacing.sm) {
                TextField("Ask AI...", text: $inputText, axis: .vertical)
                    .font(MemoraTypography.chatBody)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .onSubmit { send() }

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? MemoraColor.textTertiary : MemoraColor.interactivePrimary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.md)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.bottom, MemoraSpacing.sm)
        }
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        isFocused = false
        onSend?(trimmed)
    }
}
