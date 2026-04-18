import SwiftUI
import SwiftData

/// 生成フロー選択シート（ハーフモーダル + Nothing Style + Liquid Glass）
struct GenerationFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool

    let onStart: (GenerationConfig) -> Void

    @Query(sort: \CustomSummaryTemplate.createdAt, order: .forward) private var customTemplates: [CustomSummaryTemplate]

    @State private var selectedTemplate: GenerationTemplate = .summary
    @State private var selectedCustomTemplateID: UUID? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("テンプレートを選択")
                    .font(MemoraTypography.phiTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, MemoraSpacing.lg)
                    .padding(.top, MemoraSpacing.lg)
                    .padding(.bottom, MemoraSpacing.sm)

                ScrollView {
                    VStack(spacing: MemoraSpacing.sm) {
                        ForEach(GenerationTemplate.allCases, id: \.self) { template in
                            builtInTemplateCard(template)
                        }

                        if !customTemplates.isEmpty {
                            ForEach(customTemplates) { template in
                                customTemplateCard(template)
                            }
                        }
                    }
                    .padding(.horizontal, MemoraSpacing.md)
                }

                Spacer()

                PillButton(title: "生成開始", action: {
                    var config = GenerationConfig()
                    if let customID = selectedCustomTemplateID,
                       let custom = customTemplates.first(where: { $0.id == customID }) {
                        config.customPrompt = custom.prompt
                        config.customOutputSections = custom.outputSections
                    }
                    config.template = selectedTemplate
                    onStart(config)
                    isPresented = false
                }, style: .nothing)
                .padding(.horizontal, MemoraSpacing.lg)
                .padding(.vertical, MemoraSpacing.md)
            }
            .navigationTitle("要約を生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .nothingTheme(showDotMatrix: true)
    }

    // MARK: - Template Card

    private func builtInTemplateCard(_ template: GenerationTemplate) -> some View {
        let isSelected = selectedCustomTemplateID == nil && selectedTemplate == template
        return Button {
            selectedTemplate = template
            selectedCustomTemplateID = nil
        } label: {
            HStack(spacing: 0) {
                // Left-edge accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? MemoraColor.accentNothing : Color.clear)
                    .frame(width: 4)
                    .padding(.vertical, MemoraSpacing.sm)

                HStack(spacing: MemoraSpacing.md) {
                    Image(systemName: template.icon)
                        .font(MemoraTypography.phiSubhead)
                        .foregroundStyle(isSelected ? MemoraColor.accentNothing : MemoraColor.textSecondary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                        Text(template.title)
                            .font(MemoraTypography.phiBody)
                            .foregroundStyle(MemoraColor.textPrimary)

                        Text(template.description)
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(MemoraColor.textSecondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentNothing)
                    }
                }
                .padding(MemoraSpacing.md)
            }
        }
        .buttonStyle(.plain)
        .glassCard(.default)
    }

    private func customTemplateCard(_ template: CustomSummaryTemplate) -> some View {
        let isSelected = selectedCustomTemplateID == template.id
        return Button {
            selectedCustomTemplateID = template.id
            selectedTemplate = .summary
        } label: {
            HStack(spacing: 0) {
                // Left-edge accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? MemoraColor.accentNothing : Color.clear)
                    .frame(width: 4)
                    .padding(.vertical, MemoraSpacing.sm)

                HStack(spacing: MemoraSpacing.md) {
                    Image(systemName: "doc.text.fill")
                        .font(MemoraTypography.phiSubhead)
                        .foregroundStyle(isSelected ? MemoraColor.accentNothing : MemoraColor.textSecondary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                        Text(template.name)
                            .font(MemoraTypography.phiBody)
                            .foregroundStyle(MemoraColor.textPrimary)

                        Text(template.prompt)
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(MemoraColor.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentNothing)
                    }
                }
                .padding(MemoraSpacing.md)
            }
        }
        .buttonStyle(.plain)
        .glassCard(.default)
    }
}

// MARK: - Generation Config

struct GenerationConfig {
    var template: GenerationTemplate = .summary
    var customPrompt: String?
    var customOutputSections: [String]?
    var language: String = "ja"
    var includeSpeakers: Bool = true
    var autoCreateTodos: Bool = true
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

#Preview {
    GenerationFlowSheet(isPresented: .constant(true)) { _ in }
}
