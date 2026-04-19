import SwiftUI

// MARK: - Debug Section

struct DebugSection: View {
    @Bindable var state: SettingsState

    var body: some View {
        Section {
            NavigationLink {
                DebugLogView()
            } label: {
                HStack {
                    Image(systemName: "ladybug")
                        .foregroundStyle(MemoraColor.accentNothing)
                    Text("デバッグログ")
                    Spacer()
                    if let lastLog = DebugLogger.shared.logs.last {
                        Text("\(lastLog.message)")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Text("アプリ初回起動時のパフォーマンスを確認できます")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        } header: {
            GlassSectionHeader(title: "デバッグ", icon: "ladybug")
        }
    }
}
