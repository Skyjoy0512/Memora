import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProjectsViewModel()
    @State private var showCreateProjectView = false
    @State private var selectedProject: Project?
    @Query private var audioFiles: [AudioFile]
    @Binding var isTabBarHidden: Bool

    init(isTabBarHidden: Binding<Bool> = .constant(false)) {
        self._isTabBarHidden = isTabBarHidden
    }

    private let columns = [
        GridItem(.flexible(), spacing: MemoraSpacing.md),
        GridItem(.flexible(), spacing: MemoraSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let errorMessage = viewModel.lastErrorMessage {
                    InlineErrorMessage(message: errorMessage)
                        .padding(.horizontal, MemoraSpacing.md)
                        .padding(.top, MemoraSpacing.sm)
                }

                if viewModel.projects.isEmpty {
                    // 空の状態
                    VStack(spacing: MemoraSpacing.xxl) {
                        Spacer()

                        EmptyStateView(
                            icon: "folder",
                            title: "プロジェクト",
                            description: "プロジェクトを作成して録音を整理しましょう",
                            buttonTitle: "プロジェクトを作成",
                            buttonAction: { showCreateProjectView = true }
                        )

                        Text("まだプロジェクトがありません")
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(MemoraColor.textTertiary)
                            .padding(.bottom, MemoraSpacing.xl)
                    }
                } else {
                    // プロジェクト一覧 — 2-column grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: MemoraSpacing.md) {
                            ForEach(viewModel.projects) { project in
                                Button {
                                    selectedProject = project
                                } label: {
                                    ProjectCard(project: project, fileCount: fileCount(for: project))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("プロジェクトを開く")
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let index = viewModel.projects.firstIndex(of: project) {
                                            deleteProjects(at: IndexSet(integer: index))
                                        }
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, MemoraSpacing.md)
                        .padding(.top, MemoraSpacing.sm)
                    }
                }
            }
            .navigationTitle("プロジェクト")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateProjectView = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(MemoraColor.accentNothing)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showCreateProjectView) {
            CreateProjectView {
                viewModel.loadProjects()
            }
        }
        .navigationDestination(item: $selectedProject) { project in
            ProjectDetailView(project: project)
                .toolbar(.hidden, for: .tabBar)
                .onAppear { isTabBarHidden = true }
                .onDisappear { isTabBarHidden = false }
        }
        .task {
            viewModel.configure(projectRepository: ProjectRepository(modelContext: modelContext))
            viewModel.loadProjects()
        }
        .onChange(of: selectedProject?.id) { _, projectID in
            if projectID == nil {
                viewModel.loadProjects()
            }
        }
    }

    private func fileCount(for project: Project) -> Int {
        audioFiles.filter { $0.projectID == project.id }.count
    }

    private func deleteProjects(at offsets: IndexSet) {
        viewModel.deleteProjects(at: offsets, from: viewModel.projects)
    }
}

// MARK: - Inline Error Message

struct InlineErrorMessage: View {
    let message: String

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MemoraColor.accentRed)

            Text(message)
                .font(MemoraTypography.phiCaption)
                .foregroundStyle(MemoraColor.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.sm)
        .background(MemoraColor.accentRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
    }
}

// MARK: - Project Card (Nothing Style)

struct ProjectCard: View {
    let project: Project
    var fileCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            // Icon
            Image(systemName: "folder.fill")
                .font(.system(size: MemoraSize.iconMedium))
                .foregroundStyle(MemoraColor.accentNothing)

            // Title
            Text(project.title)
                .font(MemoraTypography.phiTitle)
                .foregroundStyle(MemoraColor.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: MemoraSpacing.xxs)

            // Footer: date + file count badge
            HStack {
                Text(formatDate(project.updatedAt))
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textTertiary)

                Spacer()

                if fileCount > 0 {
                    Text("\(fileCount)")
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(MemoraColor.accentNothing)
                        .padding(.horizontal, MemoraSpacing.xs)
                        .padding(.vertical, MemoraSpacing.xxxs)
                        .background(MemoraColor.accentNothingSubtle)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .nothingCard(.standard)
    }

    private static let projectDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.projectDateFormatter.string(from: date)
    }
}

// MARK: - Legacy Row (kept for backward compatibility)

struct ProjectRow: View {
    let project: Project
    var fileCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
            Text(project.title)
                .font(MemoraTypography.phiBody)
                .foregroundStyle(MemoraColor.textPrimary)
                .lineLimit(1)

            HStack(spacing: MemoraSpacing.xs) {
                Text(formatDate(project.updatedAt))
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textTertiary)

                if fileCount > 0 {
                    Text("\(fileCount)ファイル")
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(MemoraColor.textTertiary)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MemoraSpacing.xs)
    }

    private static let projectDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.projectDateFormatter.string(from: date)
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: Project.self, inMemory: true)
}
