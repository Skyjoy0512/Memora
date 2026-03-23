import SwiftUI

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterTranscribed: Bool?
    @Binding var filterSummarized: Bool?

    var body: some View {
        NavigationStack {
            VStack(spacing: 21) {
                Spacer()

                // 文字起こしステータス
                VStack(alignment: .leading, spacing: 13) {
                    Text("文字起こしステータス")
                        .font(.headline)

                    HStack(spacing: 8) {
                        filterButton(title: "すべて", selected: filterTranscribed == nil)
                        filterButton(title: "済み", selected: filterTranscribed == true)
                        filterButton(title: "未済み", selected: filterTranscribed == false)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(13)

                // 要約ステータス
                VStack(alignment: .leading, spacing: 13) {
                    Text("要約ステータス")
                        .font(.headline)

                    HStack(spacing: 8) {
                        filterButton(title: "すべて", selected: filterSummarized == nil)
                        filterButton(title: "済み", selected: filterSummarized == true)
                        filterButton(title: "未済み", selected: filterSummarized == false)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(13)

                Spacer()

                // リセットボタン
                Button(action: resetFilters) {
                    Text("リセット")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(13)
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
                .font(.subheadline)
                .foregroundStyle(selected ?? false ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selected ?? false ? Color.gray : Color.gray.opacity(0.1))
                .cornerRadius(8)
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
