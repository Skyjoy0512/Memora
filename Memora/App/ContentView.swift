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
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
