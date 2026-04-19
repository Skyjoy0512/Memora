import SwiftUI

struct NothingGlowConfiguration {
    var color: Color = MemoraColor.accentNothingGlow
    var radius: CGFloat = 16
    var intensity: Double = 0.35
    var cornerRadius: CGFloat = MemoraRadius.md
    var animated: Bool = true

    static let `default` = NothingGlowConfiguration()
    static let subtle = NothingGlowConfiguration(radius: 8, intensity: 0.15)
    static let prominent = NothingGlowConfiguration(radius: 24, intensity: 0.5)
}

struct NothingGlowModifier: ViewModifier {
    let config: NothingGlowConfiguration

    func body(content: Content) -> some View {
        content
            .shadow(
                color: config.color.opacity(config.intensity),
                radius: config.radius
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
