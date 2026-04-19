import SwiftUI
import SwiftData

struct MemorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryFact.key) private var memoryFacts: [MemoryFact]
    @Query(sort: \MemoryProfile.createdAt, order: .forward) private var memoryProfiles: [MemoryProfile]
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = MemoryPrivacyMode.standard.rawValue

    @State private var summaryStyle = ""
    @State private var preferredLanguage = ""
    @State private var roleLabel = ""
    @State private var glossary = ""
    @State private var disabledFactIDs = DisabledMemoryFactsStore.load()
    @State private var editingDraft: MemoryFactDraft?

    private var privacyMode: MemoryPrivacyMode {
        MemoryPrivacyMode(rawValue: memoryPrivacyMode) ?? .standard
    }

    private var profile: MemoryProfile? {
        memoryProfiles.first
    }

    private var enabledFactCount: Int {
        memoryFacts.filter { !disabledFactIDs.contains($0.id) }.count
    }

    var body: some View {
        List {
            privacySection
            profileSection
            candidateSection
            savedFactsSection
        }
        .navigationTitle("Memory 設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfileFields()
            disabledFactIDs = DisabledMemoryFactsStore.load()
        }
        .sheet(item: $editingDraft) { draft in
            MemoryFactEditorSheet(
                draft: draft,
                onSave: saveFactEdits
            )
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section("プライバシーモード") {
            Picker("モード", selection: $memoryPrivacyMode) {
                ForEach(MemoryPrivacyMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title)
                            .tag(mode.rawValue)

                        Text(mode.shortDescription)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .pickerStyle(.inline)

            VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                Text(privacyMode.description)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                Text("現在: 有効 \(enabledFactCount) 件 / 無効 \(memoryFacts.count - enabledFactCount) 件")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textTertiary)
            }
            .padding(.vertical, MemoraSpacing.xxxs)
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        Section {
            TextField("要約スタイル", text: $summaryStyle)
            TextField("優先言語", text: $preferredLanguage)
            TextField("ロール・肩書き", text: $roleLabel)
            TextField("用語メモ", text: $glossary, axis: .vertical)
                .lineLimit(2...4)

            Button("プロフィール memory を保存") {
                saveProfileFields()
            }

            if hasAnyProfileField {
                Button("プロフィール memory をクリア", role: .destructive) {
                    clearProfileFields()
                }
            }
        } header: {
            Text("Profile Memory")
        } footer: {
            Text("AskAI の応答スタイルや個人設定に使う固定情報です。")
        }
    }

    @ViewBuilder
    private var candidateSection: some View {
        let candidates = memoryFacts.filter { $0.lastConfirmedAt == nil }
        if !candidates.isEmpty {
            Section {
                ForEach(candidates) { fact in
                    VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                        HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fact.key)
                                    .font(MemoraTypography.subheadline)
                                    .foregroundStyle(.primary)

                                Text(fact.value)
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Text("候補")
                                .font(MemoraTypography.caption2)
                                .foregroundStyle(MemoraColor.accentBlue)
                                .padding(.horizontal, MemoraSpacing.xs)
                                .padding(.vertical, 4)
                                .background(MemoraColor.accentBlue.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        HStack(spacing: MemoraSpacing.sm) {
                            Button {
                                fact.confirm()
                                try? modelContext.save()
                            } label: {
                                Label("承認", systemImage: "checkmark.circle")
                                    .font(MemoraTypography.caption1)
                            }
                            .buttonStyle(.bordered)
                            .tint(MemoraColor.accentGreen)

                            Button(role: .destructive) {
                                DisabledMemoryFactsStore.remove(id: fact.id)
                                disabledFactIDs.remove(fact.id)
                                modelContext.delete(fact)
                                try? modelContext.save()
                            } label: {
                                Label("却下", systemImage: "xmark.circle")
                                    .font(MemoraTypography.caption1)
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Text(fact.source)
                                .font(MemoraTypography.caption2)
                                .foregroundStyle(MemoraColor.textTertiary)
                        }
                    }
                    .padding(.vertical, MemoraSpacing.xxxs)
                }
            } header: {
                Text("承認待ち (\(candidates.count))")
            } footer: {
                Text("要約完了時に自動抽出された記憶候補です。承認すると AskAI で活用されます。")
            }
        }
    }

    @ViewBuilder
    private var savedFactsSection: some View {
        Section {
            if memoryFacts.isEmpty {
                VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                    Text("保存済み memory はまだありません。")
                        .font(MemoraTypography.subheadline)

                    Text("CL-B5 の抽出候補承認フローが入ると、ここに preference / glossary / persona が並びます。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            } else {
                ForEach(memoryFacts) { fact in
                    Button {
                        editingDraft = MemoryFactDraft(
                            id: fact.id,
                            key: fact.key,
                            value: fact.value,
                            source: fact.source,
                            confidence: fact.confidence
                        )
                    } label: {
                        MemoryFactRow(
                            fact: fact,
                            isDisabled: disabledFactIDs.contains(fact.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(disabledFactIDs.contains(fact.id) ? "有効化" : "無効化") {
                            toggleFactDisabled(fact)
                        }
                        .tint(disabledFactIDs.contains(fact.id) ? MemoraColor.accentGreen : .orange)

                        Button("削除", role: .destructive) {
                            deleteFact(fact)
                        }
                    }
                }
            }
        } header: {
            Text("保存済み Memory")
        } footer: {
            Text("無効化した memory は保持したまま AskAI の対象から外せます。")
        }
    }

    private var hasAnyProfileField: Bool {
        [summaryStyle, preferredLanguage, roleLabel, glossary]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func loadProfileFields() {
        guard let profile else {
            summaryStyle = ""
            preferredLanguage = ""
            roleLabel = ""
            glossary = ""
            return
        }

        summaryStyle = profile.summaryStyle ?? ""
        preferredLanguage = profile.preferredLanguage ?? ""
        roleLabel = profile.roleLabel ?? ""
        glossary = profile.glossaryJSON ?? ""
    }

    private func saveProfileFields() {
        let target = profile ?? {
            let newProfile = MemoryProfile()
            modelContext.insert(newProfile)
            return newProfile
        }()

        target.update(
            summaryStyle: trimmedOrNil(summaryStyle),
            preferredLanguage: trimmedOrNil(preferredLanguage),
            roleLabel: trimmedOrNil(roleLabel),
            glossaryJSON: trimmedOrNil(glossary)
        )

        try? modelContext.save()
        loadProfileFields()
    }

    private func clearProfileFields() {
        guard let profile else { return }
        profile.update(
            summaryStyle: nil,
            preferredLanguage: nil,
            roleLabel: nil,
            glossaryJSON: nil
        )
        try? modelContext.save()
        loadProfileFields()
    }

    private func saveFactEdits(_ draft: MemoryFactDraft) {
        guard let fact = memoryFacts.first(where: { $0.id == draft.id }) else { return }

        fact.key = draft.key.trimmingCharacters(in: .whitespacesAndNewlines)
        fact.value = draft.value.trimmingCharacters(in: .whitespacesAndNewlines)
        fact.source = draft.source.trimmingCharacters(in: .whitespacesAndNewlines)
        fact.confidence = draft.confidence
        try? modelContext.save()
    }

    private func toggleFactDisabled(_ fact: MemoryFact) {
        disabledFactIDs = DisabledMemoryFactsStore.toggle(id: fact.id)
    }

    private func deleteFact(_ fact: MemoryFact) {
        DisabledMemoryFactsStore.remove(id: fact.id)
        disabledFactIDs.remove(fact.id)
        modelContext.delete(fact)
        try? modelContext.save()
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct MemoryFactRow: View {
    let fact: MemoryFact
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.key)
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(isDisabled ? MemoraColor.textSecondary : .primary)

                    Text(fact.value)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Text(isDisabled ? "無効" : "有効")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(isDisabled ? .orange : MemoraColor.accentGreen)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 4)
                    .background((isDisabled ? Color.orange : MemoraColor.accentGreen).opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: MemoraSpacing.sm) {
                Label(fact.source, systemImage: "tray.full")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textSecondary)

                Label("\(Int(fact.confidence * 100))%", systemImage: "chart.bar")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
        .padding(.vertical, MemoraSpacing.xxxs)
    }
}

struct MemoryFactEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var draft: MemoryFactDraft
    let onSave: (MemoryFactDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("編集") {
                    TextField("Key", text: $draft.key)
                    TextField("Value", text: $draft.value, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Source", text: $draft.source)

                    VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                        HStack {
                            Text("Confidence")
                            Spacer()
                            Text("\(Int(draft.confidence * 100))%")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $draft.confidence, in: 0...1)
                    }
                }
            }
            .navigationTitle("Memory 編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        draft.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        draft.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

struct MemoryFactDraft: Identifiable {
    let id: UUID
    var key: String
    var value: String
    var source: String
    var confidence: Double
}

enum MemoryPrivacyMode: String, CaseIterable, Identifiable {
    case standard = "standard"
    case paused = "paused"
    case off = "off"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "標準"
        case .paused:
            return "保存停止"
        case .off:
            return "完全オフ"
        }
    }

    var shortDescription: String {
        switch self {
        case .standard:
            return "memory を保存し、AskAI に反映"
        case .paused:
            return "既存 memory は残し、新規保存を止める"
        case .off:
            return "保存も利用も停止"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "承認済み memory を AskAI に渡し、今後の抽出候補も保存対象として扱います。"
        case .paused:
            return "既存の memory は保持しますが、新しい memory 候補は保存しない前提で扱います。"
        case .off:
            return "保存済み memory を AskAI に渡さず、新規 memory 保存も停止する最も強いモードです。"
        }
    }
}

enum DisabledMemoryFactsStore {
    private static let key = "disabledMemoryFactIDs"

    static func load() -> Set<UUID> {
        Set(
            (UserDefaults.standard.stringArray(forKey: key) ?? [])
                .compactMap(UUID.init(uuidString:))
        )
    }

    @discardableResult
    static func toggle(id: UUID) -> Set<UUID> {
        var ids = load()
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        save(ids)
        return ids
    }

    static func remove(id: UUID) {
        var ids = load()
        ids.remove(id)
        save(ids)
    }

    private static func save(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString).sorted(), forKey: key)
    }
}
