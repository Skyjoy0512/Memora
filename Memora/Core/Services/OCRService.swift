import Foundation
import ImageIO
@preconcurrency import Vision

final class OCRService {
    func extractText(from imageURL: URL) async -> String? {
        await Task.detached(priority: .utility) { [imageURL] in
            guard
                let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                return nil
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ja-JP", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("[OCRService] OCR failed: \(error.localizedDescription)")
                return nil
            }

            let recognizedText = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return recognizedText.isEmpty ? nil : recognizedText
        }.value
    }
}
