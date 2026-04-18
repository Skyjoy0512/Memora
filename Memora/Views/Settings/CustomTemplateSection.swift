import SwiftUI
import SwiftData

// MARK: - Custom Template Section

struct CustomTemplateSection: View {
    @Bindable var state: SettingsState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomSummaryTemplate.createdAt, order: .forward) private var customTemplates: [CustomSummaryTemplate]

    var body: some View {
        Section {
            ForEach(customTemplates) { template in
                Button {
                    state.editingTemplate = template
                    state.templateDraftName = template.name
                    state.templateDraftPrompt = template.prompt
                    state.templateDraftSections = template.outputSections.joined(separator: "\n")
                    state.showTemplateEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                        Text(template.name)
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.primary)

                        Text(template.prompt)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .onDelete(perform: deleteCustomTemplate)

            Button {
                state.templateDraftName = ""
                state.templateDraftPrompt = ""
                state.templateDraftSections = ""
                state.editingTemplate = nil
                state.showTemplateEditor = true
            } label: {
                Label("テンプレートを追加", systemImage: "plus")
            }
        } header: {
            GlassSectionHeader(title: "要約テンプレート", icon: "doc.text")
        }
        .sheet(isPresented: $state.showTemplateEditor) {
            TemplateEditorSheet(
                templateDraftName: $state.templateDraftName,
                templateDraftPrompt: $state.templateDraftPrompt,
                templateDraftSections: $state.templateDraftSections,
                editingTemplate: state.editingTemplate,
                onSave: saveCustomTemplate
            )
        }
    }

    // MARK: - Actions

    private func deleteCustomTemplate(at offsets: IndexSet) {
        for index in offsets {
            let template = customTemplates[index]
            modelContext.delete(template)
        }
        try? modelContext.save()
    }

    private func saveCustomTemplate() {
        if let existing = state.editingTemplate {
            existing.name = state.templateDraftName
            existing.prompt = state.templateDraftPrompt
            existing.outputSections = state.templateDraftSections
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            let template = CustomSummaryTemplate(
                name: state.templateDraftName,
                prompt: state.templateDraftPrompt,
                outputSections: state.templateDraftSections
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
            modelContext.insert(template)
        }
        try? modelContext.save()
    }
}

// MARK: - Template Editor Sheet

struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var templateDraftName: String
    @Binding var templateDraftPrompt: String
    @Binding var templateDraftSections: String
    let editingTemplate: CustomSummaryTemplate?
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("テンプレート情報") {
                    TextField("名前", text: $templateDraftName)
                    TextField("プロンプト", text: $templateDraftPrompt, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("出力セクション（1行に1つ）", text: $templateDraftSections, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(editingTemplate == nil ? "テンプレート追加" : "テンプレート編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(
                        templateDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        templateDraftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
