import SwiftUI

struct PhotoAttachmentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let attachment: PhotoAttachment
    let image: UIImage?
    let canMoveLeading: Bool
    let canMoveTrailing: Bool
    let onSaveCaption: (String) -> Void
    let onMoveLeading: () -> Void
    let onMoveTrailing: () -> Void
    let onDelete: () -> Void

    @State private var captionText: String

    init(
        attachment: PhotoAttachment,
        image: UIImage?,
        canMoveLeading: Bool = false,
        canMoveTrailing: Bool = false,
        onSaveCaption: @escaping (String) -> Void,
        onMoveLeading: @escaping () -> Void = {},
        onMoveTrailing: @escaping () -> Void = {},
        onDelete: @escaping () -> Void
    ) {
        self.attachment = attachment
        self.image = image
        self.canMoveLeading = canMoveLeading
        self.canMoveTrailing = canMoveTrailing
        self.onSaveCaption = onSaveCaption
        self.onMoveLeading = onMoveLeading
        self.onMoveTrailing = onMoveTrailing
        self.onDelete = onDelete
        _captionText = State(initialValue: attachment.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MemoraSpacing.lg) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            RoundedRectangle(cornerRadius: MemoraRadius.lg)
                                .fill(MemoraColor.divider.opacity(0.16))
                                .frame(height: 240)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(.largeTitle))
                                        .foregroundStyle(MemoraColor.textSecondary)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.lg))

                    VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                        Text("キャプション")
                            .font(MemoraTypography.headline)

                        TextField("写真の内容をメモ", text: $captionText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)

                        Text("追加日: \(formattedDate(attachment.createdAt))")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(MemoraSpacing.lg)
            }
            .navigationTitle("写真プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSaveCaption(captionText)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            onMoveLeading()
                        } label: {
                            Label("前へ", systemImage: "arrow.left")
                        }
                        .disabled(!canMoveLeading)

                        Button {
                            onMoveTrailing()
                        } label: {
                            Label("次へ", systemImage: "arrow.right")
                        }
                        .disabled(!canMoveTrailing)

                        Spacer()

                        Button("削除", role: .destructive) {
                            onDelete()
                        }
                    }
                }
            }
        }
    }

    private static let previewDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年MM月dd日 HH:mm"
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.previewDateFormatter.string(from: date)
    }
}
