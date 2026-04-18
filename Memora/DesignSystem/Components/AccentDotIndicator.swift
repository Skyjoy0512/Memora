import SwiftUI

struct AccentDotIndicator: View {
    var color: Color = MemoraColor.accentNothing
    var size: CGFloat = 6
    var glowing: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .if(glowing) { view in
                view.nothingGlow(.subtle)
            }
    }
}
