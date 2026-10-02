import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

struct FileImage: View {
    let relativePath: String
    var maxPixel: CGFloat = 200
    var contentMode: ContentMode = .fit

    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: "\(relativePath)#\(Int(maxPixel))") {
            await load()
        }
    }

    private func load() async {
        let path = relativePath
        let pixels = maxPixel
        let data = await Task.detached(priority: .utility) {
            ImageStore.thumbnailData(relativePath: path, maxPixel: pixels)
        }.value
        image = data.flatMap(Self.decode)
    }

    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
