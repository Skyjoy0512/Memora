import SwiftUI
import SwiftData

/// 生成フロー選択シート（ハーフモーダル + Nothing Style + Liquid Glass）
struct GenerationFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @AppStorage("selectedProvider") private var storedProvider = "OpenAI"

    let onStart: (GenerationConfig) -> Void

    @Query(sort: \CustomSummaryTemplate.createdAt, order: .forward) private var customTemplates: [CustomSummaryTemplate]

    @State private var selectedTemplateSource: GenerationTemplateSource = .automatic
    @State private var selectedTemplate: GenerationTemplate = .summary
    @State private var selectedCustomTemplateID: UUID? = nil
    @State private var selectedProvider: AIProvider = .openai

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("要約の作成")
                    .font(MemoraTypography.phiTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, MemoraSpacing.lg)
                    .padding(.top, MemoraSpacing.lg)
                    .padding(.bottom, MemoraSpacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                        templateSourcePicker
                        templateSelectionContent
                        providerSelection
                    }
                    .padding(.horizontal, MemoraSpacing.lg)
                    .padding(.bottom, MemoraSpacing.md)
                }

                Spacer()

                PillButton(title: "生成開始", action: {
                    var config = GenerationConfig()
                    if selectedTemplateSource == .custom,
                       let customID = selectedCustomTemplateID,
                       let custom = customTemplates.first(where: { $0.id == customID }) {
                        config.customPrompt = custom.prompt
                        config.customOutputSections = custom.outputSections
                    }
                    config.template = selectedTemplateSource == .builtIn ? selectedTemplate : .summary
                    config.templateSource = selectedTemplateSource
                    config.aiProvider = selectedProvider
                    storedProvider = selectedProvider.rawValue
                    onStart(config)
                    isPresented = false
                }, style: .primary)
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
        .onAppear {
            selectedProvider = AIProvider(rawValue: storedProvider) ?? .openai
            if selectedCustomTemplateID == nil, let first = customTemplates.first {
                selectedCustomTemplateID = first.id
            }
        }
        .presentationDetents([.medium, .large])
        .nothingTheme(showDotMatrix: true)
    }

    // MARK: - Sections

    private var templateSourcePicker: some View {
        HStack(spacing: MemoraSpacing.xs) {
            ForEach(GenerationTemplateSource.allCases) { source in
                Button {
                    selectedTemplateSource = source
                    if source == .custom, selectedCustomTemplateID == nil {
                        selectedCustomTemplateID = customTemplates.first?.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: source.icon)
                            .font(MemoraTypography.caption1)
                        Text(source.title)
                            .font(MemoraTypography.caption1)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(selectedTemplateSource == source ? .white : MemoraColor.textSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .background(selectedTemplateSource == source ? MemoraColor.accentNothing : MemoraColor.divider.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var templateSelectionContent: some View {
        switch selectedTemplateSource {
        case .automatic:
            automaticTemplateCard
        case .builtIn:
            VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                sectionTitle("テンプレート")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MemoraSpacing.sm) {
                        ForEach(GenerationTemplate.allCases, id: \.self) { template in
                            builtInTemplateCard(template)
                                .frame(width: 220)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        case .custom:
            VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                sectionTitle("マイテンプレート")
                if customTemplates.isEmpty {
                    emptyCustomTemplateCard
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: MemoraSpacing.sm) {
                            ForEach(customTemplates) { template in
                                customTemplateCard(template)
                                    .frame(width: 240)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var providerSelection: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            sectionTitle("AIエンジン")
            HStack(spacing: MemoraSpacing.xs) {
                ForEach(AIProvider.allCases) { provider in
                    providerButton(provider)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(MemoraTypography.caption1)
            .fontWeight(.semibold)
            .foregroundStyle(MemoraColor.textSecondary)
    }

    private var automaticTemplateCard: some View {
        HStack(spacing: MemoraSpacing.md) {
            Image(systemName: "sparkles")
                .font(MemoraTypography.phiSubhead)
                .foregroundStyle(MemoraColor.accentNothing)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                Text("自動適用")
                    .font(MemoraTypography.phiBody)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text("内容に合わせて標準の要約形式を適用します")
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MemoraColor.accentNothing)
        }
        .padding(MemoraSpacing.md)
        .glassCard(.default)
    }

    private var emptyCustomTemplateCard: some View {
        HStack(spacing: MemoraSpacing.md) {
            Image(systemName: "doc.badge.plus")
                .font(MemoraTypography.phiSubhead)
                .foregroundStyle(MemoraColor.textSecondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                Text("マイテンプレートは未作成です")
                    .font(MemoraTypography.phiBody)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text("設定画面から用途に合わせたテンプレートを追加できます")
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
        .padding(MemoraSpacing.md)
        .glassCard(.default)
    }

    // MARK: - Template Card

    private func builtInTemplateCard(_ template: GenerationTemplate) -> some View {
        let isSelected = selectedTemplateSource == .builtIn && selectedTemplate == template
        return Button {
            selectedTemplateSource = .builtIn
            selectedTemplate = template
            selectedCustomTemplateID = nil
        } label: {
            VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                // Left-edge accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? MemoraColor.accentNothing : Color.clear)
                    .frame(height: 4)

                HStack {
                    Image(systemName: template.icon)
                        .foregroundStyle(isSelected ? MemoraColor.accentNothing : MemoraColor.textSecondary)
                    if isSelected {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentNothing)
                    }
                }

                Text(template.title)
                    .font(MemoraTypography.phiBody)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(template.description)
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textSecondary)
                    .lineLimit(3)
            }
            .padding(MemoraSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .glassCard(.default)
    }

    private func customTemplateCard(_ template: CustomSummaryTemplate) -> some View {
        let isSelected = selectedTemplateSource == .custom && selectedCustomTemplateID == template.id
        return Button {
            selectedTemplateSource = .custom
            selectedCustomTemplateID = template.id
            selectedTemplate = .summary
        } label: {
            VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                // Left-edge accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? MemoraColor.accentNothing : Color.clear)
                    .frame(height: 4)

                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(isSelected ? MemoraColor.accentNothing : MemoraColor.textSecondary)
                    if isSelected {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentNothing)
                    }
                }

                Text(template.name)
                    .font(MemoraTypography.phiBody)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(template.prompt)
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textSecondary)
                    .lineLimit(3)
            }
            .padding(MemoraSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .glassCard(.default)
    }

    private func providerButton(_ provider: AIProvider) -> some View {
        let isSelected = selectedProvider == provider
        return Button {
            selectedProvider = provider
        } label: {
            VStack(spacing: 4) {
                Image(systemName: provider.iconName)
                    .font(MemoraTypography.caption1)
                Text(provider.displayName)
                    .font(MemoraTypography.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? .white : MemoraColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isSelected ? MemoraColor.accentNothing : MemoraColor.divider.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Generation Config

struct GenerationConfig {
    var template: GenerationTemplate = .summary
    var templateSource: GenerationTemplateSource = .automatic
    var aiProvider: AIProvider?
    var customPrompt: String?
    var customOutputSections: [String]?
    var language: String = "ja"
    var includeSpeakers: Bool = true
    var autoCreateTodos: Bool = true
}

// MARK: - Generation Template

enum GenerationTemplateSource: String, CaseIterable, Identifiable {
    case automatic
    case builtIn
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自動"
        case .builtIn: return "テンプレート"
        case .custom: return "マイ"
        }
    }

    var icon: String {
        switch self {
        case .automatic: return "sparkles"
        case .builtIn: return "square.grid.2x2"
        case .custom: return "person.crop.square"
        }
    }
}

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

private extension AIProvider {
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        case .local: return "Local"
        }
    }

    var iconName: String {
        switch self {
        case .openai: return "sparkles"
        case .gemini: return "diamond"
        case .deepseek: return "brain"
        case .local: return "cpu"
        }
    }
}

#Preview {
    GenerationFlowSheet(isPresented: .constant(true)) { _ in }
}
