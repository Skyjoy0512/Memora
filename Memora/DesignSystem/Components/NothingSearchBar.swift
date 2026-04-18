import SwiftUI

struct NothingSearchBar: View {
    @Binding var text: String
    var placeholder: String = "検索"
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(MemoraTypography.phiBody)
                .foregroundStyle(MemoraColor.textTertiary)

            TextField(placeholder, text: $text)
                .font(MemoraTypography.phiBody)
                .textFieldStyle(.plain)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(MemoraTypography.phiBody)
                        .foregroundStyle(MemoraColor.accentNothing)
                }
            }
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.sm)
        .glassCard(.init(cornerRadius: MemoraRadius.pill, glow: false))
    }
}
