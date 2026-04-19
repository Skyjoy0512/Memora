import SwiftUI
import SwiftData

// MARK: - Memory Settings Section

struct MemorySettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryFact.key) private var memoryFacts: [MemoryFact]
    @Query(sort: \MemoryProfile.createdAt, order: .forward) private var memoryProfiles: [MemoryProfile]
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = MemoryPrivacyMode.standard.rawValue

    private var currentMemoryPrivacyMode: MemoryPrivacyMode {
        MemoryPrivacyMode(rawValue: memoryPrivacyMode) ?? .standard
    }

    var body: some View {
        Section {
            NavigationLink {
                MemorySettingsView()
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(MemoraColor.accentNothing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory 設定")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.primary)

                        Text("\(memoryFacts.count) 件保存・\(currentMemoryPrivacyMode.title)")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !memoryProfiles.isEmpty {
                        Text("Profile")
                            .font(MemoraTypography.caption2)
                            .foregroundStyle(MemoraColor.accentBlue)
                            .padding(.horizontal, MemoraSpacing.xs)
                            .padding(.vertical, 4)
                            .background(MemoraColor.accentBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }
        } header: {
            GlassSectionHeader(title: "Memory", icon: "brain.head.profile")
        } footer: {
            Text("AskAI に使う保存済み memory の確認、編集、無効化、削除を行えます。")
        }
    }
}
