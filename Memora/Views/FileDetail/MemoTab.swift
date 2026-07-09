import SwiftUI
import PhotosUI

/// Memo tab (`.dc.html` `fdMemoActive`): tap-to-edit freeform text + photo attach.
struct MemoTab: View {
    @Bindable var vm: FileDetailViewModel
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let onPreviewAttachment: (UUID) -> Void

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditing {
                TextEditor(text: Binding(
                    get: { vm.memoDraft },
                    set: { vm.updateMemoDraft($0) }
                ))
                .font(.system(size: 14))
                .lineSpacing(6)
                .foregroundStyle(V6Color.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(14)
                .background(V6Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous)
                        .stroke(V6Color.ink, lineWidth: 1)
                }

                Button {
                    vm.saveMemo()
                    isEditing = false
                } label: {
                    Text("保存")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(V6Color.ink, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
                }
                .buttonStyle(V6ScalePressButtonStyleShared())
            } else {
                Button {
                    isEditing = true
                } label: {
                    Text(vm.memoDraft.isEmpty ? "タップしてメモを追加" : vm.memoDraft)
                        .font(.system(size: 14))
                        .lineSpacing(6)
                        .foregroundStyle(vm.memoDraft.isEmpty ? V6Color.quiet : V6Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(hex: "FAFAFA"), in: RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            photosSection
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var photosSection: some View {
        if vm.photoAttachments.isEmpty {
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous)
                    .fill(V6Color.faint)
                    .aspectRatio(16 / 10, contentMode: .fill)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(V6Color.quiet)
                            Text("写真を添付")
                                .font(.system(size: 12.5))
                                .foregroundStyle(V6Color.quiet)
                        }
                    }
            }
            .buttonStyle(.plain)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.photoAttachments) { attachment in
                        Button {
                            onPreviewAttachment(attachment.id)
                        } label: {
                            FileDetailHelpers.memoThumbnail(for: attachment)
                                .frame(width: 132, height: 98)
                                .clipShape(RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                        RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous)
                            .strokeBorder(Color(hex: "D9D9D9"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(width: 98, height: 98)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(V6Color.quiet)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
