import SwiftUI

/// タブ項目のプロトコル。SF Symbols モーフィングアニメーションに必要。
protocol MorphingTabProtocol: CaseIterable, Hashable {
    var symbolImage: String { get }
}

/// カスタムモーフィングタブバー。
/// UISegmentedControl の SF Symbols 自動モーフィングを活用し、
/// FAB 展開時は ExpandableGlassEffect でアクショングリッドに変形する。
struct MorphingTabBar<Tab: MorphingTabProtocol, ExpandedContent: View>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    @ViewBuilder var expandedContent: ExpandedContent

    @State private var viewWidth: CGFloat?

    var body: some View {
        ZStack {
            let symbols = Array(Tab.allCases).compactMap { $0.symbolImage }
            let selectedIndex = Binding {
                symbols.firstIndex(of: activeTab.symbolImage) ?? 0
            } set: { index in
                activeTab = Array(Tab.allCases)[index]
            }

            if let viewWidth {
                let progress: CGFloat = isExpanded ? 1 : 0
                let labelSize = CGSize(width: viewWidth, height: 52)
                let cornerRadius = labelSize.height / 2

                ExpandableGlassEffect(
                    alignment: .center,
                    progress: progress,
                    labelSize: labelSize,
                    cornerRadius: cornerRadius
                ) {
                    expandedContent
                } label: {
                    MorphingSegmentedControl(
                        symbols: symbols,
                        index: selectedIndex
                    ) { image in
                        let font = UIFont.systemFont(ofSize: 19)
                        let config = UIImage.SymbolConfiguration(font: font)
                        return UIImage(systemName: image, withConfiguration: config)
                    }
                    .frame(height: 48)
                    .padding(.horizontal, 2)
                    .offset(y: -0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ViewWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(ViewWidthKey.self) { width in
            viewWidth = width
        }
        .frame(height: viewWidth == nil ? 52 : nil)
    }
}

// MARK: - UISegmentedControl Wrapper

private struct MorphingSegmentedControl: UIViewRepresentable {
    var tint: Color = .gray.opacity(0.15)
    let symbols: [String]
    @Binding var index: Int
    let image: (String) -> UIImage?

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: symbols)
        control.selectedSegmentIndex = index
        control.selectedSegmentTintColor = UIColor(tint)
        control.backgroundColor = .clear
        control.setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
        control.setDividerImage(
            UIImage(),
            forLeftSegmentState: .normal,
            rightSegmentState: .normal,
            barMetrics: .default
        )

        for (i, symbol) in symbols.enumerated() {
            control.setImage(image(symbol), forSegmentAt: i)
        }

        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didSelect(_:)),
            for: .valueChanged
        )

        DispatchQueue.main.async {
            for view in control.subviews.dropLast() {
                if view is UIImageView {
                    view.alpha = 0
                }
            }
        }

        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != index {
            uiView.selectedSegmentIndex = index
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UISegmentedControl,
        context: Context
    ) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    final class Coordinator: NSObject {
        let parent: MorphingSegmentedControl
        init(parent: MorphingSegmentedControl) {
            self.parent = parent
        }

        @objc func didSelect(_ control: UISegmentedControl) {
            parent.index = control.selectedSegmentIndex
        }
    }
}

private struct ViewWidthKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}
