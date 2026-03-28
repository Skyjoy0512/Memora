import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct ContentView: View {
    @StateObject private var bluetoothService = BluetoothAudioService()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: MainTab = .files
    @State private var isExpanded: Bool = false
    @State private var showRecording = false
    @State private var showFileImporter = false

    var body: some View {
        mainTabView
            .overlay {
                // 展開中の背景タップで閉じる
                if isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
                                isExpanded = false
                            }
                        }
                        .ignoresSafeArea()
                }
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 12) {
                    MorphingTabBar(activeTab: $selectedTab, isExpanded: $isExpanded) {
                        actionGrid
                    }

                    Button {
                        withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .medium))
                            .rotationEffect(.init(degrees: isExpanded ? 45 : 0))
                            .frame(width: 52, height: 52)
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(GlassButtonStyle(shape: .circle))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 25)
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .environmentObject(bluetoothService)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: audioContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
    }

    // MARK: - Audio Content Types
    private var audioContentTypes: [UTType] {
        [.mpeg4Audio, .wav, .mp3, .aiff]
            .compactMap { $0 }
    }

    // MARK: - Import Handling
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importAudioFile(from: url)
        case .failure(let error):
            print("インポートエラー: \(error)")
        }
    }

    private func importAudioFile(from url: URL) {
        // セキュリティスコープアクセス
        guard url.startAccessingSecurityScopedResource() else {
            print("セキュリティスコープアクセス失敗")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // Documents ディレクトリにコピー
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let destinationName = "\(fileName)_\(UUID().uuidString.prefix(8)).\(ext)"
            let destinationURL = documentsDir.appendingPathComponent(destinationName)

            // 既存ファイルがあれば削除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: url, to: destinationURL)

            // 音声の長さを取得
            let asset = AVAsset(url: destinationURL)
            let duration = CMTimeGetSeconds(asset.duration)

            // AudioFile を SwiftData に保存
            let audioFile = AudioFile(title: fileName, audioURL: destinationURL.path)
            audioFile.duration = duration
            modelContext.insert(audioFile)
            try? modelContext.save()

            // Files タブに切り替え
            selectedTab = .files

            print("インポート完了: \(fileName) (\(String(format: "%.1f", duration))秒)")
        } catch {
            print("インポート処理エラー: \(error)")
        }
    }

    // MARK: - TabView
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(showRecordingFromFAB: $showRecording)
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("Files", systemImage: "folder.fill") }
                .tag(MainTab.files)

            ProjectsView()
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("Projects", systemImage: "rectangle.stack.fill") }
                .tag(MainTab.projects)

            ToDoView()
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("ToDo", systemImage: "checkmark.circle") }
                .tag(MainTab.todo)

            SettingsView()
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
    }

    // MARK: - Action Grid
    @ViewBuilder
    private var actionGrid: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                actionGridContent
            }
            .padding(10)
        } else {
            actionGridContent
                .padding(10)
        }
    }

    private var actionGridContent: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(spacing: 10), count: 2),
            spacing: 10
        ) {
            ActionGridButton(icon: "mic.fill", title: "録音") {
                withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
                    isExpanded = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedTab = .files
                    showRecording = true
                }
            }
            ActionGridButton(icon: "square.and.arrow.down", title: "インポート") {
                withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
                    isExpanded = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showFileImporter = true
                }
            }
        }
    }
}

// MARK: - Action Grid Button
private struct ActionGridButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(Color.primary)
                    .background(.gray.opacity(0.09), in: .rect(cornerRadius: 16))
                Text(title)
                    .font(.system(size: 9))
            }
        }
        .buttonStyle(GlassButtonStyle(shape: .rect(cornerRadius: 16)))
    }
}

// MARK: - SpeechAPIInfoView

struct SpeechAPIInfoView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("SpeechAnalyzer API チェック")
                .font(MemoraTypography.title2)
                .fontWeight(.semibold)

            Divider()

            if #available(iOS 26.0, *) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentGreen)
                        Text("iOS 26 対応デバイス")
                            .font(MemoraTypography.body)
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                Text("iOS 26 SpeechAnalyzer API を使用した強力な文字起こしが可能です。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(MemoraColor.accentBlue)
                        Text("iOS 10-25 対応デバイス")
                            .font(MemoraTypography.body)
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
                Text("現在は SFSpeechRecognizer を使用し、SpeechAnalyzer 非対応端末をカバーします。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            }

            Divider()

            Text("iOS バージョン: \(UIDevice.current.systemVersion)")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)

            Button("OK", role: .cancel) { }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .padding()
    }
}

#Preview {
    SpeechAPIInfoView()
}
