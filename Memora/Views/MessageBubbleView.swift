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
                    .font(MemoraTypography.body)
                    .foregroundStyle(isUser ? .white : MemoraColor.textPrimary)
                    .lineSpacing(4)
                    .padding(MemoraSpacing.md)
                    .frame(maxWidth: isUser ? 300 : .infinity, alignment: isUser ? .trailing : .leading)
                    .if(isUser) { view in
                        view
                            .background(MemoraColor.accentNothing)
                            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                            .nothingGlow(.subtle)
                    }
                    .if(!isUser) { view in
                        view
                            .nothingCard(.standard)
                    }

                if !message.citations.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: MemoraSpacing.xs) {
                            ForEach(message.citations) { citation in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(citation.sourceLabel)
                                        .font(MemoraTypography.caption2)
                                        .foregroundStyle(MemoraColor.accentNothing)
                                    Text(citation.title)
                                        .font(MemoraTypography.caption2)
                                        .foregroundStyle(MemoraColor.textSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, MemoraSpacing.xs)
                                .padding(.vertical, 6)
                                .glassCard(.init(cornerRadius: MemoraRadius.sm, glow: false))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: isUser ? 300 : .infinity, alignment: isUser ? .trailing : .leading)

            if isUser { Spacer(minLength: 0) }
        }
        .padding(.horizontal, MemoraSpacing.lg)
    }
}
