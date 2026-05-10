import SwiftUI

struct MeetingCaptureSection: View {
    @AppStorage("meetingCaptureAutoTranscribe") private var autoTranscribe = true
    @AppStorage("meetingCaptureDefaultPlatform") private var defaultPlatform = MeetingPlatform.other.rawValue

    var body: some View {
        Section {
            Picker("デフォルトプラットフォーム", selection: $defaultPlatform) {
                ForEach(MeetingPlatform.allCases, id: \.self) { platform in
                    HStack(spacing: 6) {
                        Image(systemName: platform.iconName)
                        Text(platform.displayName)
                    }
                    .tag(platform.rawValue)
                }
            }

            Toggle("キャプチャ後 自動で文字起こし", isOn: $autoTranscribe)

            NavigationLink {
                MeetingHistoryView()
            } label: {
                Label("会議履歴", systemImage: "clock.arrow.circlepath")
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("使い方", systemImage: "info.circle")
                    .font(.subheadline.weight(.medium))

                Text("1. Filesタブの「+」から「会議キャプチャ」を選択\n2. プラットフォームと会議名を入力\n3. 「キャプチャ開始」をタップ\n4. コントロールセンターからブロードキャストを開始\n5. 会議終了後にブロードキャストを停止すると自動で文字起こしが開始されます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            GlassSectionHeader(title: "会議キャプチャ", icon: "waveform.circle.fill")
        }
    }
}

#Preview {
    List {
        MeetingCaptureSection()
    }
}
