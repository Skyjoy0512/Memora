import SwiftUI
import UIKit

/// Plain document/chat rendering (`.dc.html` Ask tab): question = small grey text,
/// answer = body text + source chips + copy/taskify row — not rounded chat bubbles,
/// visually consistent with the Dynamic Island's Ask answer style.
struct MessageBubbleView: View {
    let message: AskAIConversationMessage
    let onTaskify: (AskAIConversationMessage) -> Void
    let onOpenSource: (AskAICitation) -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        if message.role == .user {
            Text(message.content)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(V6Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(message.content)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .foregroundStyle(V6Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !message.citations.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.citations) { citation in
                            Button {
                                onOpenSource(citation)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc")
                                        .font(.system(size: 9))
                                    Text(citation.sourceLabel)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(V6Color.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(V6Color.faint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(hex: "ECECEC"), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 14) {
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Text("コピー")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(V6Color.muted)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onTaskify(message)
                    } label: {
                        Text("タスク化")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(V6Color.muted)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(Self.timeFormatter.string(from: message.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundStyle(V6Color.neutralBorder)
                }
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(V6Color.faint).frame(height: 1)
            }
        }
    }
}
