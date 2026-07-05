import SwiftUI

// MARK: - File Detail Tab

enum FileDetailTab: String, CaseIterable, Identifiable, Hashable {
    case summary
    case transcript
    case memo

    var id: Self { self }

    var title: String {
        switch self {
        case .summary:
            return "要約"
        case .transcript:
            return "文字起こし"
        case .memo:
            return "メモ"
        }
    }

    var icon: String {
        switch self {
        case .summary:
            return "text.quote"
        case .transcript:
            return "text.alignleft"
        case .memo:
            return "square.and.pencil"
        }
    }

    /// Returns the tabs that should be visible for a given generation state.
    /// タブは常時3つ固定。生成状態による増減はさせない（PLAUD 同等の予測可能性）。
    static func availableTabs(for state: GenerationState) -> [FileDetailTab] {
        FileDetailTab.allCases
    }
}
