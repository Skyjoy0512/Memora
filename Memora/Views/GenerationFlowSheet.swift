import SwiftUI

/// 生成フロー選択シート（仕様書 §5.5 FILE-04,05,06）
struct GenerationFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool

    let onStart: (GenerationConfig) -> Void

    @State private var step = 0
    @State private var config = GenerationConfig()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.vertical, MemoraSpacing.md)

                // Step content
                Group {
                    switch step {
                    case 0: templateStep
                    case 1: optionsStep
                    case 2: confirmStep
                    default: EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)

                // Bottom buttons
                HStack {
                    if step > 0 {
                        Button("戻る") {
                            withAnimation { step -= 1 }
                        }
                        .foregroundStyle(MemoraColor.textSecondary)
                    }

                    Spacer()

                    if step < 2 {
                        Button("次へ") {
                            withAnimation { step += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MemoraColor.accentBlue)
                    } else {
                        Button("生成開始") {
                            onStart(config)
                            isPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MemoraColor.accentBlue)
                    }
                }
                .padding()
            }
            .navigationTitle("生成設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: MemoraSpacing.xxxs) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: MemoraRadius.xxs)
                    .fill(i <= step ? MemoraColor.accentBlue : MemoraColor.divider)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, MemoraSpacing.xl)
    }

    // MARK: - Step 0: Template Selection

    private var templateStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                Text("テンプレートを選択")
                    .font(MemoraTypography.headline)
                    .padding(.horizontal)

                ForEach(GenerationTemplate.allCases, id: \.self) { template in
                    templateCard(template)
                }
            }
            .padding(.vertical, MemoraSpacing.sm)
        }
    }

    private func templateCard(_ template: GenerationTemplate) -> some View {
        Button {
            config.template = template
        } label: {
            HStack(spacing: MemoraSpacing.md) {
                Image(systemName: template.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(config.template == template ? MemoraColor.accentBlue : MemoraColor.textSecondary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                    Text(template.title)
                        .font(MemoraTypography.body)
                        .foregroundStyle(MemoraColor.textPrimary)

                    Text(template.description)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)
                }

                Spacer()

                if config.template == template {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MemoraColor.accentBlue)
                }
            }
            .padding(MemoraSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MemoraRadius.md)
                    .fill(config.template == template ? MemoraColor.accentBlue.opacity(MemoraOpacity.light) : MemoraColor.divider.opacity(MemoraOpacity.subtle))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MemoraRadius.md)
                    .stroke(config.template == template ? MemoraColor.accentBlue : Color.clear, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Step 1: Options

    private var optionsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MemoraSpacing.xl) {
                // Language
                VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                    Text("言語")
                        .font(MemoraTypography.headline)

                    Picker("言語", selection: $config.language) {
                        Text("日本語").tag("ja")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // Include speakers
                if config.template != .summary {
                    Toggle(isOn: $config.includeSpeakers) {
                        VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                            Text("話者ラベルを含める")
                                .font(MemoraTypography.body)
                            Text("文字起こしの話者名を要約に反映します")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                }

                // Auto-create TodoItems
                Toggle(isOn: $config.autoCreateTodos) {
                    VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                        Text("アクションアイテムをToDoに追加")
                            .font(MemoraTypography.body)
                        Text("抽出されたアクションアイテムを自動的にTodoItemとして作成します")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textSecondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, MemoraSpacing.sm)
        }
    }

    // MARK: - Step 2: Confirm

    private var confirmStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MemoraSpacing.xl) {
                Text("生成内容の確認")
                    .font(MemoraTypography.headline)
                    .padding(.horizontal)

                confirmRow("テンプレート", value: config.template.title)
                confirmRow("言語", value: config.language == "ja" ? "日本語" : "English")
                confirmRow("話者ラベル", value: config.includeSpeakers ? "あり" : "なし")
                confirmRow("ToDo自動作成", value: config.autoCreateTodos ? "オン" : "オフ")

                VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                    Text("生成されるセクション")
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(MemoraColor.textSecondary)
                        .padding(.horizontal)

                    ForEach(config.template.outputSections, id: \.self) { section in
                        HStack(spacing: MemoraSpacing.sm) {
                            Image(systemName: "checkmark")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentGreen)
                            Text(section)
                                .font(MemoraTypography.body)
                        }
                        .padding(.horizontal, MemoraSpacing.xxl)
                    }
                }
            }
            .padding(.vertical, MemoraSpacing.sm)
        }
    }

    private func confirmRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(MemoraTypography.body)
                .foregroundStyle(MemoraColor.textSecondary)
            Spacer()
            Text(value)
                .font(MemoraTypography.body)
                .foregroundStyle(MemoraColor.textPrimary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Generation Config

struct GenerationConfig {
    var template: GenerationTemplate = .summary
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
