import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct ContentView: View {
    @StateObject private var bluetoothService = BluetoothAudioService()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.repositoryFactory) private var repositoryFactory
    @State private var selectedTab: MainTab = .files
    @State private var isExpanded: Bool = false
    @State private var showRecording = false
    @State private var showFileImporter = false

    var body: some View {
        mainTabView
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    // 展開中の背景タップで閉じる（FABの下に配置）
                    if isExpanded {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isExpanded = false
                                }
                            }
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }

                    // タブバー + FAB
                    HStack(alignment: .bottom, spacing: 12) {
                        MorphingTabBar(activeTab: $selectedTab, isExpanded: $isExpanded) {
                            actionGrid
                        }

                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 19, weight: .medium))
                                .rotationEffect(.init(degrees: isExpanded ? 45 : 0))
                                .frame(width: 52, height: 52)
                                .contentShape(Circle())
                                .foregroundStyle(Color.primary)
                        }
                        .buttonStyle(FABButtonStyle(isExpanded: isExpanded))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 25)
                }
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

            // AudioFile を保存
            let audioFile = AudioFile(title: fileName, audioURL: destinationURL.path)
            audioFile.duration = duration
            if let factory = repositoryFactory {
                try? factory.audioFileRepo.save(audioFile)
            } else {
                modelContext.insert(audioFile)
                try? modelContext.save()
            }

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

// MARK: - FAB Button Style

/// 押下フィードバック付きのFAB専用ボタンのスタイル
/// - 押下時に0.88倍に縮小してタッチフィードバックを提供
/// - Glass エフェクト(iOS 26+) / UltraThinMaterial で背景を描画
private struct FABButtonStyle: ButtonStyle {
    var isExpanded: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .background {
                fabBackground
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
    }

    @ViewBuilder
    private var fabBackground: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.ultraThinMaterial)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
        }
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
                        Image(systemName: SpeechAnalyzerFeatureFlag.isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(SpeechAnalyzerFeatureFlag.isEnabled ? MemoraColor.accentGreen : MemoraColor.accentRed)
                        Text("iOS 26 対応デバイス")
                            .font(MemoraTypography.body)
                    }
                    .padding()

                    if SpeechAnalyzerFeatureFlag.isEnabled {
                        Text("SpeechAnalyzer（ベータ）が有効です")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentGreen)
                            .padding(.horizontal)
                    } else {
                        Text("SpeechAnalyzer は現在無効です（設定から有効化可能）")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                Text("iOS 26 SpeechAnalyzer API はベータ版です。設定から有効にできます。")
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
