import SwiftUI

/// インタラクティブ要素の最小タップターゲットを44ptに保証するViewModifier。
/// iOS HIG準拠。accessibility skill推奨パターン。
struct MinimumTapTargetModifier: ViewModifier {
    let minLength: CGFloat

    init(minLength: CGFloat = 44) {
        self.minLength = minLength
    }

    func body(content: Content) -> some View {
        content
            .frame(minWidth: minLength, minHeight: minLength)
            .contentShape(Rectangle())
    }
}

extension View {
    /// 最小タップターゲット（44pt）を確保する
    func minimumTapTarget(_ minLength: CGFloat = 44) -> some View {
        modifier(MinimumTapTargetModifier(minLength: minLength))
    }
}
