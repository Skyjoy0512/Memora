import SwiftUI

struct NothingGlowConfiguration {
    var color: Color = MemoraColor.accentNothingGlow
    var radius: CGFloat = 4
    var intensity: Double = 0.35
    var cornerRadius: CGFloat = MemoraRadius.md
    var animated: Bool = true

    static let `default` = NothingGlowConfiguration()
    static let subtle = NothingGlowConfiguration(radius: 2, intensity: 0.15)
    static let prominent = NothingGlowConfiguration(radius: 8, intensity: 0.5)
}

struct NothingGlowModifier: ViewModifier {
    let config: NothingGlowConfiguration

    func body(content: Content) -> some View {
        content
            .shadow(
                color: MemoraColor.shadowLight,
                radius: config.radius * 0.5,
                x: 0, y: 2
            )
    }
}

extension View {
    func nothingGlow(
        _ config: NothingGlowConfiguration = .default
    ) -> some View {
        modifier(NothingGlowModifier(config: config))
    }
}
