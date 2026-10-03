import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

enum OptionFigureSplitter {
    /// 从一道图形题的图片里，按 A、B、C、D 旁边的方框把选项图裁出来。裁不齐就返回空，交给手动框。
    nonisolated static func split(_ data: Data) async -> [String: Data] {
        let payload = data
        return await Task.detached(priority: .userInitiated) {
            guard let image = imageFrom(payload) else { return [:] }
            let size = CGSize(width: image.width, height: image.height)
            let letters = letterBoxes(in: image, size: size)
            let figures = figureBoxes(in: image, size: size)
            let matched = match(letters: letters, figures: figures, size: size)
            guard Set(matched.keys) == Set(["A", "B", "C", "D"]) else { return [:] }
            var clips: [String: Data] = [:]
            let bounds = CGRect(origin: .zero, size: size)
            for (letter, rect) in matched {
                let padded = rect.insetBy(dx: -rect.width * 0.06, dy: -rect.height * 0.06).intersection(bounds).integral
                guard padded.width > 8, padded.height > 8, let cropped = image.cropping(to: padded), let jpeg = jpeg(from: cropped) else {
                    return [:]
                }
                clips[letter] = jpeg
            }
            return clips
        }.value
    }

    nonisolated private static func letterBoxes(in image: CGImage, size: CGSize) -> [LetterBox] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        let areaLimit = size.width * size.height * 0.03
        return (request.results ?? []).compactMap { observation in
            let raw = observation.topCandidates(1).first?.string ?? ""
            let letter = raw
                .uppercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet.punctuationCharacters)
            guard ["A", "B", "C", "D"].contains(letter) else { return nil }
            let rect = imageRect(observation.boundingBox, size: size)
            guard rect.width * rect.height < areaLimit else { return nil }
            return LetterBox(letter: letter, rect: rect)
        }
    }

    nonisolated private static func figureBoxes(in image: CGImage, size: CGSize) -> [CGRect] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.35
        request.maximumAspectRatio = 1.8
        request.minimumSize = 0.06
        request.maximumObservations = 24
        request.minimumConfidence = 0.4
        request.quadratureTolerance = 25
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        let imageArea = size.width * size.height
        return (request.results ?? []).map { imageRect($0.boundingBox, size: size) }.filter { rect in
            let area = rect.width * rect.height
            return area > imageArea * 0.008 && area < imageArea * 0.22
        }
    }

    nonisolated private static func match(letters: [LetterBox], figures: [CGRect], size: CGSize) -> [String: CGRect] {
        let limit = max(size.width, size.height) * 0.18
        var pairs: [(letter: LetterBox, figure: CGRect, gap: CGFloat)] = []
        for letter in letters {
            for figure in figures {
                let gap = edgeGap(letter.rect, figure)
                let figureIsBigger = figure.width * figure.height > letter.rect.width * letter.rect.height * 2
                if gap < limit, figureIsBigger {
                    pairs.append((letter, figure, gap))
                }
            }
        }
        pairs.sort { $0.gap < $1.gap }
        var usedLetters = Set<String>()
        var usedFigures: [CGRect] = []
        var result: [String: CGRect] = [:]
        for pair in pairs {
            if usedLetters.contains(pair.letter.letter) { continue }
            if usedFigures.contains(where: { $0.intersects(pair.figure.insetBy(dx: 4, dy: 4)) }) { continue }
            usedLetters.insert(pair.letter.letter)
            usedFigures.append(pair.figure)
            result[pair.letter.letter] = pair.figure
        }
        return result
    }

    nonisolated private static func edgeGap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = max(b.minX - a.maxX, a.minX - b.maxX, 0)
        let dy = max(b.minY - a.maxY, a.minY - b.maxY, 0)
        return hypot(dx, dy)
    }

    nonisolated private static func imageRect(_ box: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: box.minX * size.width,
            y: (1 - box.maxY) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }

    nonisolated private static func imageFrom(_ data: Data) -> CGImage? {
        let prepared = ImageStore.normalizedJPEG(from: data) ?? data
        guard let source = CGImageSourceCreateWithData(prepared as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    nonisolated private static func jpeg(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

private struct LetterBox {
    var letter: String
    var rect: CGRect
}
