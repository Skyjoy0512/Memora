import SwiftUI

struct NothingDotMatrixConfiguration {
    var dotSize: CGFloat = 1.5
    var spacing: CGFloat = 12
    var color: Color = MemoraColor.dotMatrixPrimary
    var accentInterval: Int = 7
    var accentColor: Color = MemoraColor.dotMatrixAccent

    static let `default` = NothingDotMatrixConfiguration()
    static let prominent = NothingDotMatrixConfiguration(
        dotSize: 2,
        spacing: 10,
        accentInterval: 5
    )
}

struct NothingDotMatrixModifier: ViewModifier {
    let config: NothingDotMatrixConfiguration

    func body(content: Content) -> some View {
        content
            .overlay {
                DotMatrixGrid(config: config)
                    .allowsHitTesting(false)
            }
    }
}

private struct DotMatrixGrid: View {
    let config: NothingDotMatrixConfiguration

    var body: some View {
        EmptyView()
    }
}

extension View {
    func nothingDotMatrix(
        _ config: NothingDotMatrixConfiguration = .default
    ) -> some View {
        modifier(NothingDotMatrixModifier(config: config))
    }
}
