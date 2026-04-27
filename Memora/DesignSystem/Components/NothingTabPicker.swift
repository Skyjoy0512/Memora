import SwiftUI

/// ChatGPT Design System — Segmented Control (Pill variant)
/// Pill-shaped tabs with white selected indicator + subtle shadow.
struct NothingTabPicker<T: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: T
    let options: [NothingTabOption<T>]
    var size: Size = .regular

    struct NothingTabOption<Value> {
        let value: Value
        let label: String
        let icon: String?

        init(value: Value, label: String, icon: String? = nil) {
            self.value = value
            self.label = label
            self.icon = icon
        }
    }

    enum Size {
        case regular    // h44, 14pt font, px24
        case compact    // h36, 13pt font, px16
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = selection == option.value

                Button {
                    MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                        selection = option.value
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let icon = option.icon {
                            Image(systemName: icon)
                                .font(size == .regular
                                    ? MemoraTypography.chatSegmentSmall
                                    : MemoraTypography.chatSegmentSmall)
                        }
                        Text(option.label)
                            .font(size == .regular
                                ? MemoraTypography.chatSegment
                                : MemoraTypography.chatSegmentSmall)
                    }
                    .foregroundStyle(MemoraColor.textPrimary)
                    .padding(.horizontal, size == .regular ? 24 : 16)
                    .padding(.vertical, size == .regular ? 8 : 6)
                    .background(
                        isSelected ? MemoraColor.segmentSelected : Color.clear
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: isSelected ? MemoraColor.shadowSegment : .clear,
                        radius: isSelected ? 5 : 0, x: 0, y: 2
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            MemoraColor.segmentBg,
            in: Capsule()
        )
    }
}
