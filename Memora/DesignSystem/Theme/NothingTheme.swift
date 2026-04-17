import SwiftUI

struct NothingThemeModifier: ViewModifier {
    var showDotMatrix: Bool = false

    func body(content: Content) -> some View {
        content
            .background(MemoraColor.surfacePrimary)
            .if(showDotMatrix) { view in
                view.nothingDotMatrix()
            }
    }
}

enum NothingTheme {
    static let defaultCard = GlassCardConfiguration.default
    static let heroCard = GlassCardConfiguration.prominent
    static let interactiveGlow = NothingGlowConfiguration.default
    static let subtleGlow = NothingGlowConfiguration.subtle
    static let defaultDotMatrix = NothingDotMatrixConfiguration.default
}

extension View {
    func nothingTheme(showDotMatrix: Bool = false) -> some View {
        modifier(NothingThemeModifier(showDotMatrix: showDotMatrix))
    }
}
