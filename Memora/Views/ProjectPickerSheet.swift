import SwiftUI

struct ProjectPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projects: [Project]
    @Binding var selectedProject: Project?
    @State private var tempSelection: Project?

    var body: some View {
        NavigationStack {
            List {
                if projects.isEmpty {
                    // プロジェクトがない場合
                    Section {
                        Button("プロジェクトを選択しない") {
                            selectedProject = nil
                            dismiss()
                        }
                    }

                    Section {
                        HStack {
                            Spacer()

                            VStack(spacing: MemoraSpacing.xs) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundStyle(MemoraColor.textSecondary)

                                Text("新しいプロジェクトを作成")
                                    .font(MemoraTypography.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(MemoraSpacing.xxxl)
                } else {
                    // プロジェクト一覧
                    Section {
                        Button("プロジェクトを選択しない") {
                            selectedProject = nil
                            dismiss()
                        }
                    }

                    ForEach(projects) { project in
                        Button(action: {
                            selectedProject = project
                            dismiss()
                        }) {
                            HStack(spacing: MemoraSpacing.sm) {
                                Image(systemName: "folder")
                                    .foregroundStyle(MemoraColor.textSecondary)
                                    .frame(width: 30)

                                Text(project.title)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if project.id == selectedProject?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(MemoraColor.textSecondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("プロジェクトを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            tempSelection = selectedProject
        }
    }
}

#Preview {
    ProjectPickerSheet(
        projects: [
            Project(title: "テストプロジェクト1"),
            Project(title: "テストプロジェクト2")
        ],
        selectedProject: .constant(nil)
    )
}
