import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Files", systemImage: "doc.text")
                }
            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - SpeechAnalyzer API Info View

struct SpeechAPIInfoView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("SpeechAnalyzer API チェック")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            if #available(iOS 26.0, *) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("iOS 26 対応デバイス")
                            .font(.body)
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )

                Text("iOS 26 SpeechAnalyzer API を使用した強力な文字起こしが可能です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("iOS 10-25 対応デバイス")
                            .font(.body)
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )

                Text("現在は iOS 10+ の SFSpeechRecognizer を使用した実装となっています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            }

            Divider()

            Text("iOS バージョン: \(UIDevice.current.systemVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("OK", role: .cancel) { }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
    }
}

// Preview extension for SpeechAPIInfoView
#Preview {
    SpeechAPIInfoView()
}
