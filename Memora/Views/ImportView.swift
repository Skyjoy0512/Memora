import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Import View (Document Picker Wrapper)

struct ImportView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImport: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .audio,
            .mp3,
            .wav,
            .aiff,
            .mpeg4Audio,
            UTType("public.mpeg-4-audio") ?? .audio,
            UTType("public.aac-audio") ?? .audio
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onImport: onImport)
    }

    @MainActor
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let isPresented: Binding<Bool>
        let onImport: (URL) -> Void

        init(isPresented: Binding<Bool>, onImport: @escaping (URL) -> Void) {
            self.isPresented = isPresented
            self.onImport = onImport
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onImport(url)
            isPresented.wrappedValue = false
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            isPresented.wrappedValue = false
        }
    }
}

// MARK: - Import Service

@MainActor
final class ImportService {

    func importFile(from url: URL, repoFactory: RepositoryFactory) -> AudioFile? {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileName = url.lastPathComponent
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let uniqueName = "\(UUID().uuidString)_\(fileName)"
        let destinationURL = documentsDir.appendingPathComponent(uniqueName)

        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
        } catch {
            print("インポートコピーエラー: \(error)")
            return nil
        }

        let title = url.deletingPathExtension().lastPathComponent
        let audioFile = AudioFile(title: title, audioURL: destinationURL.path)
        audioFile.duration = getAudioDuration(url: destinationURL)

        try? repoFactory.audioFileRepo.save(audioFile)

        return audioFile
    }

    private func getAudioDuration(url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return asset.duration.seconds
    }
}
