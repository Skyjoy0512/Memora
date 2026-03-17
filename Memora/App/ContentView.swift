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

            // SettingsView() // 一時的に無効化
            //     .tabItem {
            //         Label("Settings", systemImage: "gearshape")
            //     }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}


