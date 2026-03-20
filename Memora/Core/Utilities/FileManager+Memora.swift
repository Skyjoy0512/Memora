import Foundation

extension FileManager {
    static let memora = FileManagerMemora()

    final class FileManagerMemora {
        /// 音声ファイルの保存ディレクトリ
        lazy var audioDirectory: URL = {
            let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let audioDir = supportURL.appendingPathComponent("Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
            return audioDir
        }()

        /// 添付ファイルの保存ディレクトリ
        lazy var attachmentDirectory: URL = {
            let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let attachmentDir = supportURL.appendingPathComponent("Attachments", isDirectory: true)
            try? FileManager.default.createDirectory(at: attachmentDir, withIntermediateDirectories: true)
            return attachmentDir
        }()

        /// サムネイル画像の保存ディレクトリ
        lazy var thumbnailDirectory: URL = {
            let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let thumbnailDir = supportURL.appendingPathComponent("Thumbnails", isDirectory: true)
            try? FileManager.default.createDirectory(at: thumbnailDir, withIntermediateDirectories: true)
            return thumbnailDir
        }()

        /// 一時ファイルの保存ディレクトリ
        lazy var temporaryDirectory: URL = {
            let tempURL = FileManager.default.temporaryDirectory
            let tempDir = tempURL.appendingPathComponent("Memora", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            return tempDir
        }()

        /// 音声ファイル用のユニークなファイル名を生成
        func generateAudioFileName(ext: String = "m4a") -> String {
            let timestamp = Date().timeIntervalSince1970
            return "recording_\(timestamp).\(ext)"
        }

        /// 音声ファイルを保存する
        /// - Parameters:
        ///   - data: 音声データ
        ///   - fileName: ファイル名（nilの場合は自動生成）
        /// - Returns: 保存されたファイルのパス（AudioDirectory内の相対パス）
        func saveAudioFile(data: Data, fileName: String? = nil) throws -> URL {
            let name = fileName ?? generateAudioFileName()
            let fileURL = audioDirectory.appendingPathComponent(name)
            try data.write(to: fileURL)
            return fileURL
        }

        /// 添付ファイルを保存する
        /// - Parameters:
        ///   - data: ファイルデータ
        ///   - fileName: ファイル名
        /// - Returns: 保存されたファイルのパス（AttachmentDirectory内の相対パス）
        func saveAttachment(data: Data, fileName: String) throws -> URL {
            let fileURL = attachmentDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileURL
        }

        /// サムネイル画像を保存する
        /// - Parameters:
        ///   - data: 画像データ
        ///   - fileName: ファイル名
        /// - Returns: 保存されたファイルのパス（ThumbnailDirectory内の相対パス）
        func saveThumbnail(data: Data, fileName: String) throws -> URL {
            let fileURL = thumbnailDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileURL
        }

        /// 音声ファイルを削除する
        func deleteAudioFile(at localPath: String) throws {
            let fileURL = audioDirectory.appendingPathComponent(localPath)
            try FileManager.default.removeItem(at: fileURL)
        }

        /// 添付ファイルを削除する
        func deleteAttachment(at localPath: String) throws {
            let fileURL = attachmentDirectory.appendingPathComponent(localPath)
            try FileManager.default.removeItem(at: fileURL)
        }

        /// 一時ディレクトリ内のファイルをすべて削除する
        func clearTemporaryDirectory() throws {
            let contents = try FileManager.default.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
