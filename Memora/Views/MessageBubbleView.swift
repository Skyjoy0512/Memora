import SwiftUI

struct MessageBubbleView: View {
    let message: AskAIConversationMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if !isUser { Spacer(minLength: 0) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? Color.white : Color.primary)
                    .lineSpacing(5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: isUser ? 0.85 : .infinity, alignment: isUser ? .trailing : .leading)
                    .if(isUser) { view in
                        view
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }

                if !message.citations.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(message.citations) { citation in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(citation.sourceLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(citation.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser { Spacer(minLength: 0) }
        }
        .padding(.horizontal)
    }
}
