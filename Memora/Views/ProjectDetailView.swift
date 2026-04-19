import SwiftUI
import SwiftData
import Observation
import PhotosUI

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var viewModel = ProjectDetailViewModel()
    @State private var showEditProjectView = false
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?
    @State private var showAskAI = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var previewPhotoID: UUID?

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("詳細")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .navigationDestination(isPresented: $showEditProjectView) {
            EditProjectView(project: project)
        }
        .navigationDestination(isPresented: $showRecordingView) {
            RecordingView(initialProject: project)
        }
        .sheet(isPresented: $showAskAI) {
            AskAIView(scope: .project(projectId: project.id))
        }
        .sheet(
            isPresented: Binding(
                get: { previewPhotoID != nil },
                set: { if !$0 { previewPhotoID = nil } }
            )
        ) {
            photoPreviewSheet
        }
        .navigationDestination(item: $selectedAudioFile) { file in
            FileDetailView(audioFile: file)
        }
        .task {
            viewModel.configure(
                modelContext: modelContext,
                audioFileRepository: AudioFileRepository(modelContext: modelContext)
            )
            viewModel.loadProjectFiles(projectID: project.id)
            viewModel.loadPhotoAttachments(projectID: project.id)
        }
        .onChange(of: showRecordingView) { _, isPresented in
            if !isPresented {
                viewModel.loadProjectFiles(projectID: project.id)
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await viewModel.importPhoto(from: data, projectID: project.id)
                    }
                }
                await MainActor.run {
                    selectedPhotoItems = []
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.lastErrorMessage {
                InlineErrorMessage(message: errorMessage)
                    .padding(.horizontal)
                    .padding(.top, MemoraSpacing.sm)
            }

            if viewModel.projectFiles.isEmpty {
                emptyStateView
            } else {
                fileListContent
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: MemoraSpacing.lg) {
                projectPhotoSection
                    .padding(.horizontal)
                    .padding(.top, MemoraSpacing.lg)

                Image(systemName: "folder")
                    .resizable()
                    .frame(width: MemoraSize.iconLarge, height: MemoraSize.iconLarge)
                    .foregroundStyle(MemoraColor.accentNothing)

                Text(project.title)
                    .font(MemoraTypography.phiHeadline)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text("まだファイルがありません")
                    .font(MemoraTypography.phiBody)
                    .foregroundStyle(MemoraColor.textSecondary)

                PillButton(title: "録音を開始", action: { showRecordingView = true }, style: .primary)
                    .padding(.horizontal, MemoraSpacing.md)

                Text("録音を開始してファイルを追加しましょう")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, MemoraSpacing.xxxl)
            }
        }
    }

    @ViewBuilder
    private var fileListContent: some View {
        List {
            projectPhotoSection

            Section {
                ForEach(viewModel.projectFiles) { file in
                    Button {
                        selectedAudioFile = file
                    } label: {
                        AudioFileRow(audioFile: file, projectName: project.title)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityHint("ファイル詳細を開く")
                }
                .onDelete(perform: deleteAudioFiles)
            } header: {
                GlassSectionHeader(title: "録音", icon: "waveform")
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Image(systemName: "photo.badge.plus")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button {
                showAskAI = true
            } label: {
                Image(systemName: "sparkles")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showRecordingView = true }) {
                Image(systemName: "mic")
            }
        }
    }

    @ViewBuilder
    private var photoPreviewSheet: some View {
        if let attachment = selectedPreviewAttachment() {
            PhotoAttachmentPreviewSheet(
                attachment: attachment,
                image: fullSizeImage(for: attachment),
                canMoveLeading: viewModel.canMovePhotoAttachment(attachment, towardLeading: true),
                canMoveTrailing: viewModel.canMovePhotoAttachment(attachment, towardLeading: false),
                onSaveCaption: { caption in
                    viewModel.updatePhotoCaption(attachment, caption: caption)
                },
                onMoveLeading: {
                    viewModel.movePhotoAttachment(attachment, towardLeading: true)
                },
                onMoveTrailing: {
                    viewModel.movePhotoAttachment(attachment, towardLeading: false)
                },
                onDelete: {
                    viewModel.deletePhotoAttachment(attachment)
                    previewPhotoID = nil
                }
            )
        }
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        viewModel.deleteAudioFiles(at: offsets, from: viewModel.projectFiles)
    }

    private var projectPhotoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                        Label("プロジェクト写真", systemImage: "photo.stack")
                            .font(MemoraTypography.headline)
                        Text("資料や現場写真をこのプロジェクトに残せます。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("追加", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                if viewModel.isImportingPhotos {
                    ProgressView("写真を取り込み中...")
                        .font(MemoraTypography.caption1)
                }

                if viewModel.photoAttachments.isEmpty {
                    EmptyStateView(
                        icon: "photo.badge.plus",
                        title: "写真はまだありません",
                        description: "プロジェクト単位の資料写真を追加すると、ここに表示されます。"
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: MemoraSpacing.sm) {
                            ForEach(viewModel.photoAttachments, id: \.id) { attachment in
                                Button {
                                    previewPhotoID = attachment.id
                                } label: {
                                    VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                                        thumbnail(for: attachment)
                                            .frame(width: 132, height: 98)
                                            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))

                                        Text(attachment.caption ?? "キャプションなし")
                                            .font(MemoraTypography.caption1)
                                            .foregroundStyle(MemoraColor.textPrimary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 132, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, MemoraSpacing.xxs)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.vertical, MemoraSpacing.xxxs)
        }
    }

    @ViewBuilder
    private func thumbnail(for attachment: PhotoAttachment) -> some View {
        if let image = thumbnailImage(for: attachment) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: MemoraRadius.md)
                    .fill(MemoraColor.divider.opacity(0.16))
                Image(systemName: "photo")
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
    }

    private func selectedPreviewAttachment() -> PhotoAttachment? {
        guard let previewPhotoID else { return nil }
        return viewModel.photoAttachments.first { $0.id == previewPhotoID }
    }

    private func thumbnailImage(for attachment: PhotoAttachment) -> UIImage? {
        if let thumbnailPath = attachment.thumbnailPath,
           let image = UIImage(contentsOfFile: thumbnailPath) {
            return image
        }

        return UIImage(contentsOfFile: attachment.localPath)
    }

    private func fullSizeImage(for attachment: PhotoAttachment) -> UIImage? {
        UIImage(contentsOfFile: attachment.localPath)
    }
}

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("プロジェクト名を編集")) {
                    TextField("プロジェクト名", text: $title)
                        .textFieldStyle(.plain)
                }
            }
            .navigationTitle("編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveProject()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            title = project.title
        }
    }

    private func saveProject() {
        project.title = title
        project.updatedAt = Date()
        dismiss()
    }
}

@MainActor
@Observable
final class ProjectDetailViewModel {
    @ObservationIgnored
    private var modelContext: ModelContext?
    @ObservationIgnored
    private var audioFileRepository: AudioFileRepositoryProtocol?

    var projectFiles: [AudioFile] = []
    var photoAttachments: [PhotoAttachment] = []
    var isImportingPhotos = false
    var lastErrorMessage: String?

    func configure(modelContext: ModelContext, audioFileRepository: AudioFileRepositoryProtocol?) {
        if self.modelContext == nil {
            self.modelContext = modelContext
        }
        guard self.audioFileRepository == nil else { return }
        self.audioFileRepository = audioFileRepository
    }

    func loadProjectFiles(projectID: UUID) {
        guard let audioFileRepository else { return }

        do {
            projectFiles = try audioFileRepository.fetchByProject(projectID)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "ファイルの読み込みに失敗しました。もう一度お試しください。"
            print("ファイル読み込みエラー: \(error.localizedDescription)")
        }
    }

    func deleteAudioFiles(at offsets: IndexSet, from visibleFiles: [AudioFile]) {
        for index in offsets {
            let file = visibleFiles[index]
            delete(file)
        }
    }

    private func delete(_ file: AudioFile) {
        guard let audioFileRepository else { return }

        do {
            try audioFileRepository.delete(file)
            projectFiles.removeAll(where: { $0.id == file.id })
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "ファイルの削除に失敗しました。もう一度お試しください。"
            print("ファイル削除エラー: \(error.localizedDescription)")
        }
    }

    func loadPhotoAttachments(projectID: UUID) {
        guard let modelContext else { return }

        let ownerTypeRaw = PhotoAttachmentOwnerType.project.rawValue
        var descriptor = FetchDescriptor<PhotoAttachment>(
            predicate: #Predicate {
                $0.ownerTypeRaw == ownerTypeRaw &&
                $0.ownerID == projectID
            },
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
        descriptor.fetchLimit = 100
        photoAttachments = (try? modelContext.fetch(descriptor)) ?? []
        normalizePhotoAttachmentOrder()
    }

    func importPhoto(from data: Data, projectID: UUID) async {
        guard let modelContext else { return }
        isImportingPhotos = true
        defer { isImportingPhotos = false }

        do {
            let attachment = try savePhotoAttachment(from: data, projectID: projectID, modelContext: modelContext)
            photoAttachments.insert(attachment, at: 0)
            normalizePhotoAttachmentOrder()
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "写真の追加に失敗しました。もう一度お試しください。"
            print("写真追加エラー: \(error.localizedDescription)")
        }
    }

    func updatePhotoCaption(_ attachment: PhotoAttachment, caption: String?) {
        guard let modelContext else { return }
        attachment.updateCaption(normalizedOptionalString(caption))

        do {
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "キャプションの保存に失敗しました。もう一度お試しください。"
            print("キャプション保存エラー: \(error.localizedDescription)")
        }
    }

    func deletePhotoAttachment(_ attachment: PhotoAttachment) {
        guard let modelContext else { return }

        do {
            modelContext.delete(attachment)
            photoAttachments.removeAll { $0.id == attachment.id }
            normalizePhotoAttachmentOrder()
            try modelContext.save()
            removeFileIfNeeded(at: attachment.localPath)
            removeFileIfNeeded(at: attachment.thumbnailPath)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "写真の削除に失敗しました。もう一度お試しください。"
            print("写真削除エラー: \(error.localizedDescription)")
        }
    }

    func canMovePhotoAttachment(_ attachment: PhotoAttachment, towardLeading: Bool) -> Bool {
        guard let index = photoAttachments.firstIndex(where: { $0.id == attachment.id }) else {
            return false
        }
        return towardLeading ? index > 0 : index < photoAttachments.count - 1
    }

    func movePhotoAttachment(_ attachment: PhotoAttachment, towardLeading: Bool) {
        guard let modelContext,
              let index = photoAttachments.firstIndex(where: { $0.id == attachment.id }) else { return }

        let targetIndex = towardLeading ? index - 1 : index + 1
        guard photoAttachments.indices.contains(targetIndex) else { return }

        photoAttachments.swapAt(index, targetIndex)
        normalizePhotoAttachmentOrder()

        do {
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "写真の並び替えに失敗しました。もう一度お試しください。"
            print("写真並び替えエラー: \(error.localizedDescription)")
            loadPhotoAttachments(projectID: attachment.ownerID)
        }
    }

    private func savePhotoAttachment(from data: Data, projectID: UUID, modelContext: ModelContext) throws -> PhotoAttachment {
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let directory = try photoStorageDirectory(projectID: projectID)
        let identifier = UUID().uuidString
        let imageURL = directory.appendingPathComponent("\(identifier).jpg")
        let thumbnailURL = directory.appendingPathComponent("\(identifier)_thumb.jpg")

        guard let imageData = normalizedJPEGData(from: image, compressionQuality: 0.88) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try imageData.write(to: imageURL, options: .atomic)

        let thumbnailData = thumbnailJPEGData(from: image)
        if let thumbnailData {
            try thumbnailData.write(to: thumbnailURL, options: .atomic)
        }

        let attachment = PhotoAttachment(
            ownerType: .project,
            ownerID: projectID,
            sortOrder: photoAttachments.count,
            localPath: imageURL.path,
            thumbnailPath: thumbnailData == nil ? nil : thumbnailURL.path
        )
        modelContext.insert(attachment)
        return attachment
    }

    private func photoStorageDirectory(projectID: UUID) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsDirectory
            .appendingPathComponent("MemoraPhotos", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    private func normalizedJPEGData(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return renderedImage.jpegData(compressionQuality: compressionQuality)
    }

    private func thumbnailJPEGData(from image: UIImage, maxDimension: CGFloat = 320) -> Data? {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > 0 else { return nil }

        let scale = min(1, maxDimension / longestEdge)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumbnail.jpegData(compressionQuality: 0.72)
    }

    private func normalizePhotoAttachmentOrder() {
        for (index, attachment) in photoAttachments.enumerated() {
            if attachment.sortOrder != index {
                attachment.updateSortOrder(index)
            }
        }
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func removeFileIfNeeded(at path: String?) {
        guard let path, FileManager.default.fileExists(atPath: path) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}
