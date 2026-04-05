import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct ContentView: View {
    @StateObject private var bluetoothService = BluetoothAudioService()
    @StateObject private var omiAdapter = OmiAdapter()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: MainTab = .files
    @State private var pendingOpenedAudioFileID: UUID?
    @State private var isExpanded: Bool = false
    @State private var showRecording = false
    @State private var showFileImporter = false
    @State private var importErrorMessage: String?

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
            .environmentObject(omiAdapter)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: importContentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImportResult(result)
            }
            .alert("インポートエラー", isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        importErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            } message: {
                if let importErrorMessage {
                    Text(importErrorMessage)
                }
            }
            .onAppear {
                DebugLogger.shared.markLaunchStep("ContentView.onAppear")
                // OmiAdapter 設定を遅延して起動直後の負荷を下げる
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    configureOmiAdapterIfNeeded()
                    DebugLogger.shared.markLaunchStep("OmiAdapter 設定完了（遅延）")
                }
            }
            .onChange(of: omiAdapter.lastImportedAudio) { _, importedAudio in
                guard let importedAudio else { return }
                selectedTab = .files
                pendingOpenedAudioFileID = importedAudio.audioFileID
            }
    }

    // MARK: - Import Content Types
    private var importContentTypes: [UTType] {
        [.mpeg4Audio, .wav, .mp3, .aiff, .json, .plainText]
            .compactMap { $0 }
    }

    // MARK: - Import Handling
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "aiff", "aac"]
            let plaudURLs = urls.filter { !audioExtensions.contains($0.pathExtension.lowercased()) }
            let audioURLs = urls.filter { audioExtensions.contains($0.pathExtension.lowercased()) }

            // 音声ファイルは通常インポート
            for url in audioURLs {
                importAudioFile(from: url)
            }

            // Plaud 系ファイル（JSON/TXT等）は Plaud 処理
            if !plaudURLs.isEmpty {
                importPlaudFiles(plaudURLs)
            }
        case .failure(let error):
            presentImportError(prefix: "ファイルの選択に失敗しました", error: error)
        }
    }

    private func importAudioFile(from url: URL) {
        do {
            let audioFile = try AudioFileImportService.importAudio(
                from: url,
                modelContext: modelContext,
                requiresSecurityScopedAccess: true
            )
            selectedTab = .files
            pendingOpenedAudioFileID = audioFile.id
            print("インポート完了: \(audioFile.title) (\(String(format: "%.1f", audioFile.duration))秒)")
        } catch {
            presentImportError(prefix: "音声ファイルのインポートに失敗しました", error: error)
        }
    }

    private func configureOmiAdapterIfNeeded() {
        omiAdapter.configureAudioImportHandler { sourceURL, suggestedTitle in
            try await MainActor.run {
                try AudioFileImportService.importOmiAudio(
                    from: sourceURL,
                    suggestedTitle: suggestedTitle,
                    modelContext: modelContext
                )
            }
        }
    }

    // MARK: - Plaud Import Handling
    private func importPlaudFiles(_ urls: [URL]) {
        let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "aiff", "aac"]
        let metadataExtensions: Set<String> = ["json"]
        let textExtensions: Set<String> = ["txt", "text"]

        var audioURLs: [(URL, String)] = []   // (url, filenameWithoutExt)
        var jsonURLs: [(URL, String)] = []
        var textURLs: [(URL, String)] = []

        for url in urls {
            let ext = url.pathExtension.lowercased()
            let stem = url.deletingPathExtension().lastPathComponent
            if audioExtensions.contains(ext) {
                audioURLs.append((url, stem))
            } else if metadataExtensions.contains(ext) {
                jsonURLs.append((url, stem))
            } else if textExtensions.contains(ext) {
                textURLs.append((url, stem))
            }
        }

        var lastImportedID: UUID?

        // 音声 + JSON ペアをファイル名プレフィックスでマッチング
        var matchedAudioIndices: Set<Int> = []
        var matchedJSONIndices: Set<Int> = []

        for (ai, audioInfo) in audioURLs.enumerated() {
            for (ji, jsonInfo) in jsonURLs.enumerated() where !matchedJSONIndices.contains(ji) {
                if audioInfo.1 == jsonInfo.1 || audioInfo.1.hasPrefix(jsonInfo.1) || jsonInfo.1.hasPrefix(audioInfo.1) {
                    do {
                        let audioFile = try PlaudImportService.importFromExport(
                            audioURL: audioInfo.0,
                            metadataURL: jsonInfo.0,
                            modelContext: modelContext
                        )
                        lastImportedID = audioFile.id
                        matchedAudioIndices.insert(ai)
                        matchedJSONIndices.insert(ji)
                    } catch {
                        presentImportError(prefix: "Plaud ファイルのインポートに失敗しました", error: error)
                    }
                    break
                }
            }
        }

        // マッチしなかった音声ファイルを個別インポート
        for (i, audioInfo) in audioURLs.enumerated() where !matchedAudioIndices.contains(i) {
            do {
                let audioFile = try PlaudImportService.importFromExport(
                    audioURL: audioInfo.0,
                    metadataURL: nil,
                    modelContext: modelContext
                )
                lastImportedID = audioFile.id
            } catch {
                presentImportError(prefix: "Plaud ファイルのインポートに失敗しました", error: error)
            }
        }

        // マッチしなかった JSON をテキストとしてインポート
        for (i, jsonInfo) in jsonURLs.enumerated() where !matchedJSONIndices.contains(i) {
            let audioFile = importPlaudJSON(url: jsonInfo.0, fileName: jsonInfo.1)
            lastImportedID = audioFile?.id ?? lastImportedID
        }

        // テキストファイルをインポート
        for textInfo in textURLs {
            let audioFile = importPlaudText(url: textInfo.0, fileName: textInfo.1)
            lastImportedID = audioFile?.id ?? lastImportedID
        }

        if let lastImportedID {
            selectedTab = .files
            pendingOpenedAudioFileID = lastImportedID
        }
    }

    private func importPlaudJSON(url: URL, fileName: String) -> AudioFile? {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let export = try JSONDecoder().decode(PlaudExportFile.self, from: data)

            let title = export.title ?? fileName
            let audioFile: AudioFile
            if let transcript = export.transcript, !transcript.isEmpty {
                audioFile = PlaudImportService.importTextOnly(
                    title: title,
                    textContent: transcript,
                    modelContext: modelContext
                )
                if let summary = export.summary, !summary.isEmpty {
                    audioFile.summary = summary
                    audioFile.isSummarized = true
                    try modelContext.save()
                }
            } else {
                audioFile = PlaudImportService.importTextOnly(
                    title: title,
                    textContent: export.summary ?? "",
                    modelContext: modelContext
                )
            }
            return audioFile
        } catch {
            presentImportError(prefix: "Plaud ファイルのインポートに失敗しました", error: error)
            return nil
        }
    }

    private func importPlaudText(url: URL, fileName: String) -> AudioFile? {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            let text = try String(contentsOf: url, encoding: .utf8)
            let audioFile = PlaudImportService.importTextOnly(
                title: fileName,
                textContent: text,
                modelContext: modelContext
            )
            return audioFile
        } catch {
            presentImportError(prefix: "Plaud ファイルのインポートに失敗しました", error: error)
            return nil
        }
    }

    private func presentImportError(prefix: String, error: Error) {
        importErrorMessage = "\(prefix)\n\(error.localizedDescription)"
        print("\(prefix): \(error)")
    }

    // MARK: - TabView
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                showRecordingFromFAB: $showRecording,
                pendingOpenedAudioFileID: $pendingOpenedAudioFileID
            )
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
