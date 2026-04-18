import SwiftUI

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterTranscribed: Bool?
    @Binding var filterSummarized: Bool?

    var body: some View {
        NavigationStack {
            VStack(spacing: MemoraSpacing.lg) {
                Spacer()

                // 文字起こしステータス
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    GlassSectionHeader(title: "文字起こしステータス", icon: "doc.text")

                    HStack(spacing: MemoraSpacing.sm) {
                        filterButton(title: "すべて", selected: filterTranscribed == nil)
                        filterButton(title: "済み", selected: filterTranscribed == true)
                        filterButton(title: "未済み", selected: filterTranscribed == false)
                    }
                }
                .padding(MemoraSpacing.md)
                .glassCard(.default)

                // 要約ステータス
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    GlassSectionHeader(title: "要約ステータス", icon: "sparkles")

                    HStack(spacing: MemoraSpacing.sm) {
                        summaryFilterButton(title: "すべて", selected: filterSummarized == nil)
                        summaryFilterButton(title: "済み", selected: filterSummarized == true)
                        summaryFilterButton(title: "未済み", selected: filterSummarized == false)
                    }
                }
                .padding(MemoraSpacing.md)
                .glassCard(.default)

                Spacer()

                // リセットボタン
                PillButton(title: "リセット", action: resetFilters, style: .outline)
                    .padding(.horizontal, MemoraSpacing.md)
                    .padding(.bottom, MemoraSpacing.md)
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
        .nothingTheme(showDotMatrix: true)
    }

    private func filterButton(title: String, selected: Bool?) -> some View {
        Button(action: {
            if title == "すべて" {
                filterTranscribed = nil
            } else if title == "済み" {
                filterTranscribed = true
            } else if title == "未済み" {
                filterTranscribed = false
            }
        }) {
            Text(title)
                .font(MemoraTypography.phiSubhead)
                .foregroundStyle(selected ?? false ? .white : MemoraColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MemoraSpacing.sm)
                .padding(.horizontal, MemoraSpacing.md)
                .background(
                    Capsule()
                        .fill(selected ?? false ? MemoraColor.accentNothing : Color.clear)
                )
                .overlay {
                    Capsule()
                        .stroke(
                            selected ?? false ? Color.clear : MemoraColor.divider,
                            lineWidth: 1
                        )
                }
                .clipShape(Capsule())
        }
    }

    private func summaryFilterButton(title: String, selected: Bool?) -> some View {
        Button(action: {
            if title == "すべて" {
                filterSummarized = nil
            } else if title == "済み" {
                filterSummarized = true
            } else if title == "未済み" {
                filterSummarized = false
            }
        }) {
            Text(title)
                .font(MemoraTypography.phiSubhead)
                .foregroundStyle(selected ?? false ? .white : MemoraColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MemoraSpacing.sm)
                .padding(.horizontal, MemoraSpacing.md)
                .background(
                    Capsule()
                        .fill(selected ?? false ? MemoraColor.accentNothing : Color.clear)
                )
                .overlay {
                    Capsule()
                        .stroke(
                            selected ?? false ? Color.clear : MemoraColor.divider,
                            lineWidth: 1
                        )
                }
                .clipShape(Capsule())
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
