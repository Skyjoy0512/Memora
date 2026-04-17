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
        content.overlay {
            DotMatrixGrid(config: config)
                .allowsHitTesting(false)
        }
    }
}

private struct DotMatrixGrid: View {
    let config: NothingDotMatrixConfiguration

    var body: some View {
        Canvas { context, size in
            let step = config.spacing
            let dotRadius = config.dotSize / 2
            var index = 0
            var y = step / 2
            while y < size.height {
                var x = step / 2
                while x < size.width {
                    let isAccent = index % config.accentInterval == 0
                    let color = isAccent ? config.accentColor : config.color
                    let rect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: config.dotSize,
                        height: config.dotSize
                    )
                    context.fill(Circle().path(in: rect), with: .color(color))
                    index += 1
                    x += step
                }
                y += step
            }
        }
    }
}

extension View {
    func nothingDotMatrix(
        _ config: NothingDotMatrixConfiguration = .default
    ) -> some View {
        modifier(NothingDotMatrixModifier(config: config))
    }
}
