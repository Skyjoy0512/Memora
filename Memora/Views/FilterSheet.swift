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
            Form {
                Section("文字起こしステータス") {
                    Picker("文字起こし", selection: transcribedSelection) {
                        Text("すべて").tag(FilterSelection.all)
                        Text("済み").tag(FilterSelection.on)
                        Text("未済み").tag(FilterSelection.off)
                    }
                    .pickerStyle(.segmented)
                }

                Section("要約ステータス") {
                    Picker("要約", selection: summarizedSelection) {
                        Text("すべて").tag(FilterSelection.all)
                        Text("済み").tag(FilterSelection.on)
                        Text("未済み").tag(FilterSelection.off)
                    }
                    .pickerStyle(.segmented)
                }

                Section("LifeLog") {
                    Picker("種別", selection: lifeLogSelection) {
                        Text("すべて").tag(FilterSelection.all)
                        Text("LifeLog").tag(FilterSelection.on)
                        Text("通常").tag(FilterSelection.off)
                    }
                    .pickerStyle(.segmented)

                    if !availableTags.isEmpty {
                        Picker("タグ", selection: $selectedTag) {
                            Text("すべて").tag(String?.none)
                            ForEach(availableTags, id: \.self) { tag in
                                Text(tag).tag(Optional(tag))
                            }
                        }
                    }
                }

                Section {
                    Button("リセット", action: resetFilters)
                }
            }
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

    private enum FilterSelection: Hashable {
        case all
        case on
        case off
    }

    private var transcribedSelection: Binding<FilterSelection> {
        Binding {
            selection(from: filterTranscribed)
        } set: {
            filterTranscribed = bool(from: $0)
        }
    }

    private var summarizedSelection: Binding<FilterSelection> {
        Binding {
            selection(from: filterSummarized)
        } set: {
            filterSummarized = bool(from: $0)
        }
    }

    private var lifeLogSelection: Binding<FilterSelection> {
        Binding {
            selection(from: filterLifeLog)
        } set: {
            filterLifeLog = bool(from: $0)
        }
    }

    private func selection(from value: Bool?) -> FilterSelection {
        switch value {
        case .none: return .all
        case .some(true): return .on
        case .some(false): return .off
        }
    }

    private func bool(from selection: FilterSelection) -> Bool? {
        switch selection {
        case .all: return nil
        case .on: return true
        case .off: return false
        }
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
