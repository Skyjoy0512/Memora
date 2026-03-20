import Foundation
import OSLog

extension Logger {
    static let memora = LoggerMemora.shared

    final class LoggerMemora {
        static let shared = LoggerMemora()

        private let logger = Logger(subsystem: "com.memora.app", category: "Memora")

        private init() {}

        // MARK: - Log Levels

        func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            logger.debug("\(message)", file: file, function: function, line: line)
        }

        func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            logger.info("\(message)", file: file, function: function, line: line)
        }

        func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            logger.warning("\(message)", file: file, function: function, line: line)
        }

        func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            logger.error("\(message)", file: file, function: function, line: line)
        }

        func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            logger.fault("\(message)", file: file, function: function, line: line)
        }

        // MARK: - Category Specific Logging

        func repository(_ message: String) {
            logger.debug("[Repository] \(message)")
        }

        func network(_ message: String) {
            logger.debug("[Network] \(message)")
        }

        func pipeline(_ message: String) {
            logger.info("[Pipeline] \(message)")
        }

        func audio(_ message: String) {
            logger.debug("[Audio] \(message)")
        }
    }
}
