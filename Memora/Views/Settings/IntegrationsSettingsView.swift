import SwiftUI

struct IntegrationsSettingsView: View {
    @Bindable var state: SettingsState

    var body: some View {
        Form {
            DeviceConnectionSection()
            NotionIntegrationSection(state: state)
            GoogleMeetSection(state: state)
            MeetingCaptureSection()
            Section {
                BotMeetingSection(state: state)
            } footer: {
                Text("会議 Bot は実験的な機能です。動作にはセルフホストの Bot サーバーが必要です。")
            }
        }
        .navigationTitle("連携")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdvancedSettingsView: View {
    @Bindable var state: SettingsState

    var body: some View {
        Form {
            RealtimeTranscriptionSection()
            DataManagementSection(state: state)
        }
        .navigationTitle("高度な設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct DeveloperSettingsView: View {
    @Bindable var state: SettingsState

    var body: some View {
        Form {
            DeveloperFeaturesSection(state: state)
            BLEDebugSection()
            DebugSection(state: state)
        }
        .navigationTitle("開発者")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
