import Foundation

/// ファイル選択結果を、音声と付随テキストの組み合わせごとに分類する。
/// ファイルI/Oを行わないため、UIから独立してテストできる。
enum ImportRouter {
    enum Route {
        case plaudExport(audio: URL, json: URL)
        case plaudTranscript(audio: URL, text: URL)
        case audioOnly(URL)
        case textOnly(URL)
    }

    private static let audioExtensions: Set<String> = [
        "m4a", "wav", "mp3", "aac", "caf", "aiff"
    ]

    static func route(_ urls: [URL]) -> [Route] {
        let groups = Dictionary(grouping: urls) { url in
            url.deletingPathExtension().lastPathComponent
        }

        return groups.keys.sorted().flatMap { basename in
            let group = (groups[basename] ?? []).sorted { $0.path < $1.path }
            var jsonFiles = group.filter { $0.pathExtension.lowercased() == "json" }
            var textFiles = group.filter { $0.pathExtension.lowercased() == "txt" }
            let audioFiles = group.filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            var routes: [Route] = []

            for audio in audioFiles {
                if let json = jsonFiles.first {
                    jsonFiles.removeFirst()
                    routes.append(.plaudExport(audio: audio, json: json))
                } else if let text = textFiles.first {
                    textFiles.removeFirst()
                    routes.append(.plaudTranscript(audio: audio, text: text))
                } else {
                    routes.append(.audioOnly(audio))
                }
            }

            // 同名ファイルが複数あっても、未使用のテキストを捨てない。
            routes += jsonFiles.map(Route.textOnly)
            routes += textFiles.map(Route.textOnly)
            return routes
        }
    }
}
