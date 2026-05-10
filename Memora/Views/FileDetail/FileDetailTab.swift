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
    static func availableTabs(for state: GenerationState) -> [FileDetailTab] {
        switch state {
        case .notGenerated, .loading:
            return [.transcript, .memo]
        case .generated, .choosingMode, .choosingTemplate, .choosingModel:
            return [.summary, .transcript, .memo]
        }
    }
}
