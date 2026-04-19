import SwiftUI
import PhotosUI

// MARK: - Memo Tab

struct MemoTab: View {
    @Bindable var vm: FileDetailViewModel
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var previewPhotoID: UUID?

    var body: some View {
        VStack(spacing: MemoraSpacing.lg) {
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    // メモヘッダー
                    HStack(alignment: .top) {
                        Label("Markdown メモ", systemImage: "square.and.pencil")
                            .font(MemoraTypography.headline)

                        Spacer()

                        Button("保存") {
                            vm.saveMemo()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.memoHasUnsavedChanges)
                    }

                    TextEditor(text: Binding(
                        get: { vm.memoDraft },
                        set: { vm.updateMemoDraft($0) }
                    ))
                    .font(MemoraTypography.body)
                    .frame(minHeight: 220)
                    .padding(MemoraSpacing.sm)
                    .background(MemoraColor.divider.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                    .scrollContentBackground(.hidden)

                    HStack(spacing: MemoraSpacing.xs) {
                        Circle()
                            .fill(vm.memoHasUnsavedChanges ? MemoraColor.accentRed : MemoraColor.accentGreen)
                            .frame(width: 8, height: 8)

                        Text(FileDetailHelpers.memoStatusText(vm: vm))
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 写真セクション（Memo 文脈に溶け込ませる）
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    HStack {
                        Label("写真", systemImage: "photo.on.rectangle")
                            .font(MemoraTypography.headline)

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

                    if vm.isImportingPhotos {
                        ProgressView("写真を取り込み中...")
                            .font(MemoraTypography.caption1)
                    }

                    if vm.photoAttachments.isEmpty {
                        Text("写真を追加するとメモと一緒に確認できます")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, MemoraSpacing.sm)
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: MemoraSpacing.sm) {
                                ForEach(vm.photoAttachments, id: \.id) { attachment in
                                    Button {
                                        previewPhotoID = attachment.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                                            FileDetailHelpers.memoThumbnail(for: attachment)
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
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { previewPhotoID != nil },
                set: { if !$0 { previewPhotoID = nil } }
            )
        ) {
            if let attachment = selectedPreviewAttachment {
                PhotoAttachmentPreviewSheet(
                    attachment: attachment,
                    image: FileDetailHelpers.fullSizeImage(for: attachment),
                    canMoveLeading: vm.canMovePhotoAttachment(attachment, towardLeading: true),
                    canMoveTrailing: vm.canMovePhotoAttachment(attachment, towardLeading: false),
                    onSaveCaption: { caption in
                        vm.updatePhotoCaption(attachment, caption: caption)
                    },
                    onMoveLeading: {
                        vm.movePhotoAttachment(attachment, towardLeading: true)
                    },
                    onMoveTrailing: {
                        vm.movePhotoAttachment(attachment, towardLeading: false)
                    },
                    onDelete: {
                        vm.deletePhotoAttachment(attachment)
                        previewPhotoID = nil
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private func selectedPreviewAttachment(in vm: FileDetailViewModel) -> PhotoAttachment? {
        guard let previewPhotoID else { return nil }
        return vm.photoAttachments.first { $0.id == previewPhotoID }
    }

    private var selectedPreviewAttachment: PhotoAttachment? {
        selectedPreviewAttachment(in: vm)
    }

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(MemoraSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MemoraColor.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.lg))
    }
}
