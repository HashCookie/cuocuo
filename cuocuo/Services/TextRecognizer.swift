import Foundation
import Vision

enum TextRecognizer {
    /// Returns recognized text, or nil when the page has no readable text or recognition fails.
    nonisolated static func recognizeText(in data: Data) async -> String? {
        let payload = data
        return await Task.detached(priority: .userInitiated) {
            syncRecognize(payload)
        }.value
    }

    nonisolated private static func syncRecognize(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(data: data, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results, !observations.isEmpty else { return nil }
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
