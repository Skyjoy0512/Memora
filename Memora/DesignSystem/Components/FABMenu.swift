import SwiftUI

struct FABMenu: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .accessibilityLabel("メニュー背景")
                    .accessibilityHint("メニューを閉じるにはタップしてください")
                    .onTapGesture { MemoraAnimation.animate(reduceMotion) { isExpanded = false } }
            }

            // Sub items
            VStack(spacing: MemoraSpacing.sm) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        item.action()
                        MemoraAnimation.animate(reduceMotion) { isExpanded = false }
                    } label: {
                        HStack(spacing: MemoraSpacing.sm) {
                            Text(item.label)
                                .font(MemoraTypography.subheadline)
                                .foregroundStyle(MemoraColor.textPrimary)

                            Circle()
                                .fill(MemoraColor.accentNothing)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: item.icon)
                                        .font(MemoraTypography.body)
                                        .foregroundStyle(.white)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.label)
                    .opacity(isExpanded ? 1 : 0)
                    .offset(y: isExpanded ? 0 : 10)
                    .animation(
                        reduceMotion ? nil : MemoraAnimation.springDefault,
                        value: isExpanded
                    )
                }
            }
            .padding(.bottom, 72)

            // Main FAB
            Button {
                MemoraAnimation.animate(reduceMotion) {
                    isExpanded.toggle()
                }
            } label: {
                Circle()
                    .fill(MemoraColor.accentPrimary)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "plus")
                            .font(MemoraTypography.title2)
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isExpanded ? 45 : 0))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("アクションメニュー")
            .accessibilityHint(isExpanded ? "メニューを閉じる" : "録音やインポートなどのアクションを開く")
        }
    }
}
