import SwiftUI

// MARK: - Ask AI Compact Bar (inline text field)

struct AskAICompactBar: View {
    let provider: AIProvider
    let showAskAI: Binding<Bool>
    var onSend: ((String) -> Void)? = nil
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            TextField("Ask AI...", text: $inputText, axis: .vertical)
                .font(MemoraTypography.body)
                .lineLimit(1...4)
                .focused($isFocused)
                .onSubmit { send() }

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : MemoraColor.accentNothing)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.sm)
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        isFocused = false
        onSend?(trimmed)
    }
}
