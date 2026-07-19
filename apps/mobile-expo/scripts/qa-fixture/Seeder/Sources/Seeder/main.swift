import Foundation
import MemoraSharedData
import MemoraSharedSchema
import SwiftData

/// 共有SwiftDataストアへ、音声＋時刻付き文字起こしのフィクスチャを投入する。
/// usage: Seeder <appGroupPath> <audioPath> <segmentsJSON> <title> [referenceTranscriptPath]
struct Segment: Codable {
    let start: Double
    let speaker: String
    let text: String
    let end: Double
}

let args = CommandLine.arguments
guard args.count >= 5 else {
    FileHandle.standardError.write(Data("usage: Seeder <appGroupPath> <audioPath> <segmentsJSON> <title> [referenceTranscript]\n".utf8))
    exit(2)
}

let appGroup = URL(fileURLWithPath: args[1])
let sourceAudio = URL(fileURLWithPath: args[2])
let segments = try JSONDecoder().decode([Segment].self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
let title = args[4]
let reference = args.count > 5 ? try? String(contentsOfFile: args[5], encoding: .utf8) : nil

let audioDirectory = MemoraSharedStoreLocation.audioFilesDirectory(in: appGroup)
try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
let destination = audioDirectory.appendingPathComponent(sourceAudio.lastPathComponent)
if FileManager.default.fileExists(atPath: destination.path) {
    try FileManager.default.removeItem(at: destination)
}
try FileManager.default.copyItem(at: sourceAudio, to: destination)

let container = try MemoraSharedStoreFactory.makePersistentContainer(
    at: MemoraSharedStoreLocation.storeURL(in: appGroup)
)
let context = ModelContext(container)

let audioFile = AudioFile(title: title, audioURL: destination.path)
audioFile.duration = segments.last?.end ?? 0
audioFile.isTranscribed = !segments.isEmpty
audioFile.referenceTranscript = reference
audioFile.referenceSpeakerCount = Set(segments.map(\.speaker)).count
context.insert(audioFile)

if !segments.isEmpty {
    let transcript = Transcript(
        audioFileID: audioFile.id,
        text: segments.map(\.text).joined(separator: "\n")
    )
    transcript.audioFile = audioFile
    transcript.replaceSpeakerSegments(
        speakerLabels: segments.map(\.speaker),
        startTimes: segments.map(\.start),
        endTimes: segments.map(\.end),
        texts: segments.map(\.text)
    )
    context.insert(transcript)
}

try context.save()
print(audioFile.id.uuidString)
