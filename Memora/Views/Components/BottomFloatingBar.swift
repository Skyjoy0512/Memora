//
//  BottomFloatingBar.swift
//  Memora
//  MorphingTabBar + ExpandableGlassEffect based on MorphingTabBarEffect reference
//

import SwiftUI

// MARK: - MorphingTabProtocol

protocol MorphingTabProtocol: CaseIterable, Hashable {
    var symbolImage: String { get }
}

// MARK: - MainTab

enum MainTab: String, MorphingTabProtocol {
    case files = "Files"
    case projects = "Projects"
    case todo = "ToDo"
    case settings = "Setting"

    var symbolImage: String {
        switch self {
        case .files: return "folder.fill"
        case .projects: return "rectangle.stack.fill"
        case .todo: return "checkmark.circle"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - MorphingTabBar

struct MorphingTabBar<Tab: MorphingTabProtocol, ExpandedContent: View>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    @ViewBuilder var expandedContent: ExpandedContent
    @State private var viewWidth: CGFloat?

    var body: some View {
        ZStack {
            let allCases = Array(Tab.allCases)
            let symbols = allCases.compactMap { $0.symbolImage }
            let selectedIndex = Binding {
                symbols.firstIndex(of: activeTab.symbolImage) ?? 0
            } set: { index in
                activeTab = allCases[index]
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
                    CustomSegmentedTabBar(
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
                Color.clear
                    .onAppear { viewWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in
                        viewWidth = newWidth
                    }
            }
        )
        .frame(height: viewWidth == nil ? 52 : nil)
    }
}

// MARK: - UISegmentedControl Tab Bar

fileprivate struct CustomSegmentedTabBar: UIViewRepresentable {
    var tint: Color = .gray.opacity(0.15)
    var symbols: [String]
    @Binding var index: Int
    var image: (String) -> UIImage?

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: symbols)
        control.selectedSegmentIndex = index
        control.selectedSegmentTintColor = UIColor(tint)
        for (i, symbol) in symbols.enumerated() {
            control.setImage(image(symbol), forSegmentAt: i)
        }
        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.didSelect(_:)),
            for: .valueChanged
        )
        DispatchQueue.main.async {
            for view in control.subviews.dropLast() {
                if view is UIImageView { view.alpha = 0 }
            }
        }
        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != index {
            uiView.selectedSegmentIndex = index
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject {
        let parent: CustomSegmentedTabBar
        init(parent: CustomSegmentedTabBar) { self.parent = parent }
        @objc func didSelect(_ control: UISegmentedControl) {
            parent.index = control.selectedSegmentIndex
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

// MARK: - ExpandableGlassEffect

struct ExpandableGlassEffect<Content: View, Label: View>: View, Animatable {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    @State private var contentSize: CGSize = .zero

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Group {
            #if swift(>=6.2)
            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    morphingContent
                }
                .compositingGroup()
                .clipShape(.rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                morphingContent
                    .compositingGroup()
                    .clipShape(.rect(cornerRadius: cornerRadius))
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            }
            #else
            morphingContent
                .compositingGroup()
                .clipShape(.rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            #endif
        }
        .scaleEffect(
            x: 1 - (blurProgress * 0.5),
            y: 1 + (blurProgress * 0.35),
            anchor: scaleAnchor
        )
        .offset(y: offset * blurProgress)
    }

    private var morphingContent: some View {
        let widthDiff = contentSize.width - labelSize.width
        let heightDiff = contentSize.height - labelSize.height
        let rWidth = widthDiff * contentOpacity
        let rHeight = heightDiff * contentOpacity

        return ZStack(alignment: alignment) {
            content
                .compositingGroup()
                .scaleEffect(contentScale)
                .blur(radius: 14 * blurProgress)
                .opacity(contentOpacity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { contentSize = geo.size }
                            .onChange(of: geo.size) { _, newSize in
                                contentSize = newSize
                            }
                    }
                )
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
    }

    var labelOpacity: CGFloat { min(progress / 0.35, 1) }
    var contentOpacity: CGFloat { max(progress - 0.35, 0) / 0.65 }

    var contentScale: CGFloat {
        let minAspect = min(
            labelSize.width / max(contentSize.width, 1),
            labelSize.height / max(contentSize.height, 1)
        )
        return minAspect + (1 - minAspect) * progress
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

// MARK: - Glass Button Style

struct GlassButtonStyle<S: Shape>: ButtonStyle {
    var shape: S
    func makeBody(configuration: Configuration) -> some View {
        #if swift(>=6.2)
        if #available(iOS 26.0, *) {
            configuration.label
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            configuration.label
                .background(.ultraThinMaterial, in: shape)
        }
        #else
        configuration.label
            .background(.ultraThinMaterial, in: shape)
        #endif
    }
}
