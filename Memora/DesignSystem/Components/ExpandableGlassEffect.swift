import SwiftUI

/// MorphingTabBar の折りたたみ/展開アニメーションを司るコンポーネント。
/// - iOS 26+: GlassEffectContainer + .glassEffect() によるガラスモーフィング
/// - iOS 17: .ultraThinMaterial によるマテリアル拡張アニメーション
struct ExpandableGlassEffect<Content: View, Label: View>: View, Animatable {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder let content: Content
    @ViewBuilder let label: Label

    @State private var contentSize: CGSize = .zero

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            ios26Body
        } else {
            ios17Body
        }
    }

    // MARK: - iOS 26+ (Glass Effect)

    @available(iOS 26.0, *)
    private var ios26Body: some View {
        GlassEffectContainer {
            let widthDiff = contentSize.width - labelSize.width
            let heightDiff = contentSize.height - labelSize.height
            let rWidth = widthDiff * contentOpacity
            let rHeight = heightDiff * contentOpacity

            ZStack(alignment: alignment) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .background(sizeTracker)
                    .onPreferenceChange(ContentSizeKey.self) { size in
                        contentSize = size
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        width: labelSize.width + rWidth,
                        height: labelSize.height + rHeight
                    )

                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: cornerRadius))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
        .scaleEffect(
            x: 1 - (blurProgress * 0.5),
            y: 1 + (blurProgress * 0.35),
            anchor: scaleAnchor
        )
        .offset(y: offset * blurProgress)
    }

    // MARK: - iOS 17 Fallback (Material)

    private var ios17Body: some View {
        let widthDiff = contentSize.width - labelSize.width
        let heightDiff = contentSize.height - labelSize.height
        let rWidth = widthDiff * contentOpacity
        let rHeight = heightDiff * contentOpacity

        return ZStack(alignment: alignment) {
            content
                .compositingGroup()
                .scaleEffect(contentScale)
                .opacity(contentOpacity)
                .background(sizeTracker)
                .onPreferenceChange(ContentSizeKey.self) { size in
                    contentSize = size
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    width: labelSize.width + rWidth,
                    height: labelSize.height + rHeight
                )

            label
                .compositingGroup()
                .opacity(1 - labelOpacity)
                .frame(width: labelSize.width, height: labelSize.height)
        }
        .compositingGroup()
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    // MARK: - Helpers

    private var sizeTracker: some View {
        GeometryReader { geo in
            Color.clear.preference(key: ContentSizeKey.self, value: geo.size)
        }
    }

    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }

    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }

    var contentScale: CGFloat {
        let minAspectScale = min(
            labelSize.width / max(contentSize.width, 1),
            labelSize.height / max(contentSize.height, 1)
        )
        return minAspectScale + (1 - minAspectScale) * progress
    }

    var blurProgress: CGFloat {
        progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }

    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: return -80
        case .top, .topLeading, .topTrailing: return 80
        default: return -10
        }
    }

    var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

private struct ContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
