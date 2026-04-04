import Foundation
import os.log

/// デバッグログサービス
final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.memora.Memora", category: "Performance")
    @Published var logs: [DebugLogEntry] = []
    private var appStartTime: Date?

    private init() {
        loadLogs()
    }

    /// アプリ起動時のマーク
    func markAppStart() {
        appStartTime = Date()
        addLog("App", "アプリ起動開始", level: .info)
    }

    /// ModelContainer 初期化完了
    func markModelContainerReady() {
        guard let start = appStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        addLog("ModelContainer", "初期化完了 (\(String(format: "%.2f", duration))秒)", level: .info)
    }

    /// 起動完了
    func markAppReady() {
        guard let start = appStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        addLog("App", "起動完了 (\(String(format: "%.2f", duration))秒)", level: .info)
    }

    /// 起動中の任意ステップを計測
    func markLaunchStep(_ label: String) {
        guard let start = appStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        addLog("LaunchTiming", "\(label) (\(String(format: "%.3f", duration))秒)", level: .info)
    }

    /// 一般ログ追加
    func addLog(_ category: String, _ message: String, level: LogLevel = .info) {
        let entry = DebugLogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            category: category,
            message: message,
            level: level
        )

        DispatchQueue.main.async {
            self.logs.append(entry)
            self.saveLogs()
        }

        // OS ログにも出力
        switch level {
        case .debug:
            logger.debug("\(category): \(message)")
        case .info:
            logger.info("\(category): \(message)")
        case .warning:
            logger.warning("\(category): \(message)")
        case .error:
            logger.error("\(category): \(message)")
        }
    }

    /// ログをクリア
    func clearLogs() {
        logs.removeAll()
        saveLogs()
    }

    /// ログをエクスポート
    func exportLogs() -> URL? {
        var content = "Memora Debug Log\n"
        content += "Exported: \(Date())\n\n"

        for log in logs {
            let levelStr = "[\(log.level.rawValue.uppercased())]"
            let timeStr = ISO8601DateFormatter().string(from: log.timestamp)
            content += "\(timeStr) \(levelStr) \(log.category): \(log.message)\n"
        }

        guard let data = content.data(using: .utf8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("memora_debug_\(Int(Date().timeIntervalSince1970)).txt")
        try? data.write(to: url)
        return url
    }

    private func saveLogs() {
        // 最大100件に制限
        let limitedLogs = Array(logs.suffix(100))

        guard let data = try? JSONEncoder().encode(limitedLogs) else { return }
        UserDefaults.standard.set(data, forKey: "debugLogs")
    }

    private func loadLogs() {
        guard let data = UserDefaults.standard.data(forKey: "debugLogs"),
              let decoded = try? JSONDecoder().decode([DebugLogEntry].self, from: data) else {
            return
        }
        logs = decoded
    }
}

struct DebugLogEntry: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let category: String
    let message: String
    let level: LogLevel
}

enum LogLevel: String, Codable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
}
