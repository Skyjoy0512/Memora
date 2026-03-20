import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct MemoraApp: App {
    // SwiftDataStack の ModelContainer を使用
    let modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer

    // TCA AppStore
    @State var store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Reducer (仮実装)

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .files
    }

    enum Action {
        case selectTab(Tab)
    }

    enum Tab: Equatable {
        case files
        case projects
        case settings
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .selectTab(let tab):
                state.selectedTab = tab
                return .none
            }
        }
    }
}

// MARK: - App View

struct AppView: View {
    let store: StoreOf<AppReducer>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView(selection: viewStore.binding(\.$selectedTab, send: AppReducer.Action.selectTab)) {
                FilesView()
                    .tabItem {
                        Label("Files", systemImage: "doc.text")
                    }
                    .tag(AppReducer.Tab.files)

                ProjectsView()
                    .tabItem {
                        Label("Projects", systemImage: "folder")
                    }
                    .tag(AppReducer.Tab.projects)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppReducer.Tab.settings)
            }
        }
    }
}

// MARK: - Placeholder Views (TCA 対応が必要)

// TODO: 各 Feature Reducer と View はエージェント A/C が実装
// 以下は既存 View をそのまま使用するためのラッパー

struct FilesView: View {
    var body: some View {
        HomeView()
    }
}

struct ProjectsView: View {
    var body: some View {
        // 既存の ProjectsView を使用
        // TODO: TCA 対応の ProjectsListView に置き換え
        if let projectsView = Bundle.main.loadNibNamed("ProjectsView", owner: nil) as? UIView {
            UIViewContainer(view: projectsView)
        } else {
            Text("Projects")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        // 既存の SettingsView を使用
        // TODO: TCA 対応の SettingsView に置き換え
        if let settingsView = Bundle.main.loadNibNamed("SettingsView", owner: nil) as? UIView {
            UIViewContainer(view: settingsView)
        } else {
            Text("Settings")
        }
    }
}

// MARK: - UIView Container Helper

struct UIViewContainer: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView {
        view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
