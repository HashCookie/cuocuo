import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageStore {
    nonisolated static func normalizedJPEG(from data: Data, maxPixel: CGFloat = 2000) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return jpegData(from: source, maxPixel: maxPixel, quality: 0.82)
    }

    nonisolated static func writeNamed(_ jpeg: Data, questionID: UUID, name: String) throws -> String {
        let folder = try folderURL(questionID)
        let url = folder.appendingPathComponent(name)
        try jpeg.write(to: url, options: .atomic)
        return "\(questionID.uuidString)/\(name)"
    }

    nonisolated static func write(_ jpeg: Data, questionID: UUID, pageID: UUID) throws -> String {
        let folder = try folderURL(questionID)
        let name = pageID.uuidString + ".jpg"
        let url = folder.appendingPathComponent(name)
        try jpeg.write(to: url, options: .atomic)
        return "\(questionID.uuidString)/\(name)"
    }

    nonisolated static func fileData(relativePath: String) -> Data? {
        try? Data(contentsOf: fileURL(relativePath: relativePath))
    }

    nonisolated static func thumbnailData(relativePath: String, maxPixel: CGFloat) -> Data? {
        let url = fileURL(relativePath: relativePath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return jpegData(from: source, maxPixel: maxPixel, quality: 0.8)
    }

    nonisolated static func cleanup(questionID: UUID, keep: Set<String>) {
        guard let folder = try? folderURL(questionID) else { return }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in urls {
            let relative = "\(questionID.uuidString)/\(url.lastPathComponent)"
            if !keep.contains(relative) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        if let left = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
           left.isEmpty {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    nonisolated static func deleteFolder(questionID: UUID) {
        guard let root = try? rootURL() else { return }
        let folder = root.appendingPathComponent(questionID.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
    }

    nonisolated static func fileURL(relativePath: String) -> URL {
        let parts = relativePath.split(separator: "/").map(String.init)
        let root = (try? rootURL()) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return parts.reduce(root) { $0.appendingPathComponent($1) }
    }

    nonisolated private static func jpegData(from source: CGImageSource, maxPixel: CGFloat, quality: CGFloat) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    nonisolated private static func rootURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("Scans", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    nonisolated private static func folderURL(_ questionID: UUID) throws -> URL {
        let folder = try rootURL().appendingPathComponent(questionID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
