import SwiftUI

struct FABMenu: View {
    @Binding var isExpanded: Bool
    let items: [FABItem]

    struct FABItem: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let action: () -> Void
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Backdrop
            if isExpanded {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { isExpanded = false } }
            }

            // Sub items
            VStack(spacing: MemoraSpacing.sm) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: MemoraSpacing.sm) {
                        Text(item.label)
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(MemoraColor.textPrimary)

                        Circle()
                            .fill(MemoraColor.accentPrimary)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: item.icon)
                                    .font(MemoraTypography.body)
                                    .foregroundStyle(.white)
                            )
                    }
                    .opacity(isExpanded ? 1 : 0)
                    .offset(y: isExpanded ? 0 : 10)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.75),
                        value: isExpanded
                    )
                    .onTapGesture {
                        item.action()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { isExpanded = false }
                    }
                }
            }
            .padding(.bottom, 72)

            // Main FAB
            Circle()
                .fill(MemoraColor.accentPrimary)
                .frame(width: 56, height: 56)
                .shadow(color: MemoraColor.shadowMedium, radius: 8, x: 0, y: 4)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isExpanded ? 45 : 0))
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                }
        }
    }
}
