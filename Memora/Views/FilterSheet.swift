import SwiftUI

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterTranscribed: Bool?
    @Binding var filterSummarized: Bool?

    var body: some View {
        NavigationStack {
            VStack(spacing: MemoraSpacing.xxl) {
                Spacer()

                // 文字起こしステータス
                VStack(alignment: .leading, spacing: MemoraRadius.md) {
                    Text("文字起こしステータス")
                        .font(MemoraTypography.headline)

                    HStack(spacing: MemoraSpacing.xs) {
                        filterButton(title: "すべて", selected: filterTranscribed == nil)
                        filterButton(title: "済み", selected: filterTranscribed == true)
                        filterButton(title: "未済み", selected: filterTranscribed == false)
                    }
                }
                .padding()
                .background(MemoraColor.divider.opacity(MemoraOpacity.subtle))
                .cornerRadius(MemoraRadius.md)

                // 要約ステータス
                VStack(alignment: .leading, spacing: MemoraRadius.md) {
                    Text("要約ステータス")
                        .font(MemoraTypography.headline)

                    HStack(spacing: MemoraSpacing.xs) {
                        filterButton(title: "すべて", selected: filterSummarized == nil)
                        filterButton(title: "済み", selected: filterSummarized == true)
                        filterButton(title: "未済み", selected: filterSummarized == false)
                    }
                }
                .padding()
                .background(MemoraColor.divider.opacity(MemoraOpacity.subtle))
                .cornerRadius(MemoraRadius.md)

                Spacer()

                // リセットボタン
                Button(action: resetFilters) {
                    Text("リセット")
                        .font(MemoraTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MemoraColor.divider)
                        .cornerRadius(MemoraRadius.md)
                }
                .padding()
            }
            .padding()
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func filterButton(title: String, selected: Bool?) -> some View {
        Button(action: {
            if title == "すべて" {
                filterTranscribed = nil
                filterSummarized = nil
            } else if title == "済み" {
                filterTranscribed = true
            } else if title == "未済み" {
                filterTranscribed = false
            }
        }) {
            Text(title)
                .font(MemoraTypography.subheadline)
                .foregroundStyle(selected ?? false ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selected ?? false ? MemoraColor.divider : MemoraColor.divider.opacity(MemoraOpacity.medium))
                .cornerRadius(MemoraRadius.sm)
        }
    }

    private func resetFilters() {
        filterTranscribed = nil
        filterSummarized = nil
        dismiss()
    }
}

#Preview {
    FilterSheet(
        filterTranscribed: .constant(nil),
        filterSummarized: .constant(nil)
    )
}
