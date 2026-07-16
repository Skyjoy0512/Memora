import SwiftUI

// MARK: - Generation Config

struct GenerationConfig {
    var template: GenerationTemplate = .summary
    var customPrompt: String?
    var customOutputSections: [String]?
    var language: String = "ja"
    var includeSpeakers: Bool = true
    var autoCreateTodos: Bool = true
}

extension GenerationConfig {
    var summaryGenerationConfig: SummaryGenerationConfig {
        SummaryGenerationConfig(customPrompt: customPrompt)
    }
}

// MARK: - Generation Template

enum GenerationTemplate: String, CaseIterable {
    case summary
    case detailed
    case actionOriented

    var title: String {
        switch self {
        case .summary: return "要約"
        case .detailed: return "詳細な議事録"
        case .actionOriented: return "アクション重視"
        }
    }

    var description: String {
        switch self {
        case .summary: return "会議の要点を簡潔にまとめます"
        case .detailed: return "発言者ごとの詳細な議事録を作成します"
        case .actionOriented: return "決定事項とアクションアイテムに焦点を当てます"
        }
    }

    var icon: String {
        switch self {
        case .summary: return "doc.text"
        case .detailed: return "list.bullet.clipboard"
        case .actionOriented: return "checklist"
        }
    }

    var outputSections: [String] {
        switch self {
        case .summary:
            return ["要約", "重要ポイント", "アクションアイテム"]
        case .detailed:
            return ["会議概要", "発言者ごとの議論", "決定事項", "アクションアイテム"]
        case .actionOriented:
            return ["決定事項", "アクションアイテム", "担当者", "期限"]
        }
    }
}
