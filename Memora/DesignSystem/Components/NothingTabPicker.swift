import SwiftUI

struct NothingTabPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [NothingTabOption<T>]

    struct NothingTabOption<T> {
        let value: T
        let label: String
        let icon: String? = nil
    }

    var body: some View {
        HStack(spacing: MemoraSpacing.xxxs) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = selection == option.value

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = option.value
                    }
                } label: {
                    HStack(spacing: MemoraSpacing.xxs) {
                        if let icon = option.icon {
                            Image(systemName: icon)
                                .font(MemoraTypography.phiCaption)
                        }
                        Text(option.label)
                            .font(MemoraTypography.phiCaption)
                    }
                    .foregroundStyle(isSelected ? .white : MemoraColor.textPrimary)
                    .padding(.horizontal, MemoraSpacing.sm)
                    .padding(.vertical, MemoraSpacing.xxs)
                    .background(
                        isSelected ? MemoraColor.accentNothing : Color.clear
                    )
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(isSelected ? Color.clear : MemoraColor.divider, lineWidth: 0.5)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MemoraSpacing.xxxs)
        .glassCard(.init(cornerRadius: MemoraRadius.pill, accentTint: false, glow: false))
    }
}
