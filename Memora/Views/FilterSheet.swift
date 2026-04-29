import SwiftUI

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterTranscribed: Bool?
    @Binding var filterSummarized: Bool?
    @Binding var filterLifeLog: Bool?
    @Binding var selectedTag: String?
    let availableTags: [String]

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

                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    GlassSectionHeader(title: "LifeLog", icon: "tag")

                    HStack(spacing: MemoraSpacing.sm) {
                        lifeLogFilterButton(title: "すべて", selected: filterLifeLog == nil)
                        lifeLogFilterButton(title: "LifeLog", selected: filterLifeLog == true)
                        lifeLogFilterButton(title: "通常", selected: filterLifeLog == false)
                    }

                    if !availableTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: MemoraSpacing.xs) {
                                tagFilterButton(title: "すべて", selected: selectedTag == nil)
                                ForEach(availableTags, id: \.self) { tag in
                                    tagFilterButton(title: tag, selected: selectedTag == tag)
                                }
                            }
                        }
                    }
                }
                .padding(MemoraSpacing.md)
                .glassCard(.default)

                Spacer()

                // リセットボタン
                PillButton(title: "リセット", action: resetFilters, style: .secondary)
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

    private func lifeLogFilterButton(title: String, selected: Bool) -> some View {
        Button(action: {
            if title == "すべて" {
                filterLifeLog = nil
            } else if title == "LifeLog" {
                filterLifeLog = true
            } else if title == "通常" {
                filterLifeLog = false
            }
        }) {
            filterPill(title: title, selected: selected)
        }
    }

    private func tagFilterButton(title: String, selected: Bool) -> some View {
        Button(action: {
            selectedTag = title == "すべて" ? nil : title
        }) {
            filterPill(title: title, selected: selected)
        }
    }

    private func filterPill(title: String, selected: Bool) -> some View {
        Text(title)
            .font(MemoraTypography.phiSubhead)
            .foregroundStyle(selected ? .white : MemoraColor.textPrimary)
            .padding(.vertical, MemoraSpacing.sm)
            .padding(.horizontal, MemoraSpacing.md)
            .background(
                Capsule()
                    .fill(selected ? MemoraColor.accentNothing : Color.clear)
            )
            .overlay {
                Capsule()
                    .stroke(
                        selected ? Color.clear : MemoraColor.divider,
                        lineWidth: 1
                    )
            }
            .clipShape(Capsule())
    }

    private func resetFilters() {
        filterTranscribed = nil
        filterSummarized = nil
        filterLifeLog = nil
        selectedTag = nil
        dismiss()
    }
}

#Preview {
    FilterSheet(
        filterTranscribed: .constant(nil),
        filterSummarized: .constant(nil),
        filterLifeLog: .constant(nil),
        selectedTag: .constant(nil),
        availableTags: ["仕事", "会議", "個人"]
    )
}
