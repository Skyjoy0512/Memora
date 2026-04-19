import SwiftUI

struct NothingTabPicker<T: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: T
    let options: [NothingTabOption<T>]

    struct NothingTabOption<T> {
        let value: T
        let label: String
        let icon: String?

        init(value: T, label: String, icon: String? = nil) {
            self.value = value
            self.label = label
            self.icon = icon
        }
    }

    var body: some View {
        HStack(spacing: MemoraSpacing.xxxs) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = selection == option.value

                Button {
                    MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
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
        .background(
            MemoraColor.surfaceElevated,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(MemoraColor.divider.opacity(0.5), lineWidth: 0.5)
        }
    }
}
