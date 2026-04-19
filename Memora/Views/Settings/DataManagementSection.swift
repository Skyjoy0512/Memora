import SwiftUI

// MARK: - Data Management Section

struct DataManagementSection: View {
    @Bindable var state: SettingsState

    var body: some View {
        Section {
            Button {
                state.showDeleteAlert = true
            } label: {
                Text("API キーを削除")
            }
            .foregroundStyle(MemoraColor.accentRed)
        } header: {
            GlassSectionHeader(title: "データ管理", icon: "externaldrive")
        }
    }
}
