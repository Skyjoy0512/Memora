import SwiftUI

struct MessageBubbleView: View {
    let message: AskAIConversationMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if !isUser { Spacer(minLength: 0) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: MemoraSpacing.xs) {
                Text(message.content)
                    .font(MemoraTypography.chatMessage)
                    .foregroundStyle(isUser ? MemoraColor.interactivePrimaryLabel : MemoraColor.textPrimary)
                    .lineSpacing(5)
                    .padding(.horizontal, MemoraSpacing.md)
                    .padding(.vertical, MemoraSpacing.sm)
                    .frame(maxWidth: isUser ? 0.85 : .infinity, alignment: isUser ? .trailing : .leading)
                    .if(isUser) { view in
                        view
                            .background(MemoraColor.interactivePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                if !message.citations.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: MemoraSpacing.xs) {
                            ForEach(message.citations) { citation in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(citation.sourceLabel)
                                        .font(MemoraTypography.chatToken)
                                        .foregroundStyle(MemoraColor.textTertiary)
                                    Text(citation.title)
                                        .font(MemoraTypography.chatToken)
                                        .foregroundStyle(MemoraColor.textSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, MemoraSpacing.sm)
                                .padding(.vertical, MemoraSpacing.xs)
                                .background(MemoraColor.surfaceCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MemoraRadius.sm)
                                        .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser { Spacer(minLength: 0) }
        }
        .padding(.horizontal, MemoraSpacing.lg)
    }
}
