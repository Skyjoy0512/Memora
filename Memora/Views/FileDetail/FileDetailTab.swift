import SwiftUI

// MARK: - File Detail Tab

enum FileDetailTab: String, CaseIterable, Identifiable {
    case summary
    case transcript
    case memo

    var id: Self { self }

    var title: String {
        switch self {
        case .summary:
            return "Summary"
        case .transcript:
            return "Transcript"
        case .memo:
            return "Memo"
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
}
