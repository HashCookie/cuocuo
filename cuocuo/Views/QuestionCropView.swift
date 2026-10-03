import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum CropPurpose: Equatable {
    case question
    case rule
}

struct PendingCrop: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    var purpose: CropPurpose
}

struct QuestionCropView: View {
    let imageData: Data
    var purpose: CropPurpose
    var remaining: Int
    var titleText: String? = nil
    var confirmText: String? = nil
    var onUse: (Data) -> Void
    var onUseThenRule: ((Data) -> Void)?
    var onSkip: () -> Void
    var onCancel: () -> Void

    @State private var source: CGImage?
    @State private var display: CGImage?
    @State private var quarters = 0
    @State private var crop = CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.92)
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let display {
                    cropCanvas(display)
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    controls
                } else if failed {
                    ContentUnavailableView("这张图片打不开", systemImage: "photo", description: Text("换一张，或直接重拍这一道题。"))
                    Button("跳过这张", action: onSkip)
                        .padding()
                } else {
                    ProgressView("正在准备图片")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(.background)
            .navigationTitle(titleText ?? (purpose == .question ? "框出这一道题" : "框出规律"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
            }
        }
        .task { load() }
    }

    private func cropCanvas(_ image: CGImage) -> some View {
        GeometryReader { geometry in
            let imageSize = CGSize(width: image.width, height: image.height)
            let frame = aspectFit(imageSize, in: geometry.size)
            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                CropMask(crop: crop, imageFrame: frame)
                cropRect(in: frame)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func cropRect(in imageFrame: CGRect) -> some View {
        let rect = viewRect(for: crop, in: imageFrame)
        return ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .gesture(moveGesture(in: imageFrame))
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
            handle(.topLeft, at: CGPoint(x: rect.minX, y: rect.minY), in: imageFrame)
            handle(.topRight, at: CGPoint(x: rect.maxX, y: rect.minY), in: imageFrame)
            handle(.bottomLeft, at: CGPoint(x: rect.minX, y: rect.maxY), in: imageFrame)
            handle(.bottomRight, at: CGPoint(x: rect.maxX, y: rect.maxY), in: imageFrame)
        }
    }

    private func handle(_ corner: CropCorner, at point: CGPoint, in imageFrame: CGRect) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 22, height: 22)
            .shadow(radius: 1)
            .position(point)
            .gesture(resizeGesture(corner, in: imageFrame))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    rotate(by: -1)
                } label: {
                    Label("左转", systemImage: "rotate.left")
                }
                Spacer()
                Button {
                    rotate(by: 1)
                } label: {
                    Label("右转", systemImage: "rotate.right")
                }
            }
            .buttonStyle(.bordered)
            Button {
                useCrop(thenRule: false)
            } label: {
                Text(confirmText ?? (purpose == .question ? "使用这一题" : "使用这段规律"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if purpose == .question, let onUseThenRule {
                Button("接着框旁边的规律") {
                    useCrop(thenRule: true)
                }
                .buttonStyle(.bordered)
            }
            if remaining > 1 {
                Button("不要这张", action: onSkip)
            }
        }
        .padding()
    }

    private func load() {
        let data = imageData
        let prepared = ImageStore.normalizedJPEG(from: data) ?? data
        guard let source = cgImage(from: prepared) else {
            failed = true
            return
        }
        self.source = source
        display = source
        quarters = 0
        crop = suggestedCrop(width: source.width, height: source.height)
    }

    private func rotate(by step: Int) {
        guard let source else { return }
        quarters = (quarters + step + 4) % 4
        guard let turned = rotated(source, quarters: quarters) else { return }
        display = turned
        crop = suggestedCrop(width: turned.width, height: turned.height)
    }

    private var hint: String {
        if remaining > 1 {
            return "还有 \(remaining - 1) 张。一次只框一道。"
        }
        switch purpose {
        case .question:
            return "图形题只框题目和选项。手写的规律先留在框外。"
        case .rule:
            return "只框手写的规律或错因，不要把题目再框进来。"
        }
    }

    private func useCrop(thenRule: Bool) {
        guard let display else { return }
        let rect = pixelRect(for: crop, width: display.width, height: display.height)
        guard let cropped = display.cropping(to: rect), let data = jpegData(from: cropped) else {
            onSkip()
            return
        }
        if thenRule {
            onUseThenRule?(data)
        } else {
            onUse(data)
        }
    }

    private func moveGesture(in imageFrame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if moveOrigin == nil { moveOrigin = crop }
                let base = moveOrigin ?? crop
                let dx = value.translation.width / imageFrame.width
                let dy = value.translation.height / imageFrame.height
                crop = clamped(CGRect(x: base.minX + dx, y: base.minY + dy, width: base.width, height: base.height))
            }
            .onEnded { _ in
                moveOrigin = nil
            }
    }

    private func resizeGesture(_ corner: CropCorner, in imageFrame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeOrigin == nil { resizeOrigin = crop }
                let base = resizeOrigin ?? crop
                let dx = value.translation.width / imageFrame.width
                let dy = value.translation.height / imageFrame.height
                crop = clamped(corner.resized(base, dx: dx, dy: dy))
            }
            .onEnded { _ in
                resizeOrigin = nil
            }
    }

    @State private var moveOrigin: CGRect?
    @State private var resizeOrigin: CGRect?
}

private enum CropCorner {
    case topLeft, topRight, bottomLeft, bottomRight

    func resized(_ rect: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
        switch self {
        case .topLeft:
            return CGRect(x: rect.minX + dx, y: rect.minY + dy, width: rect.width - dx, height: rect.height - dy)
        case .topRight:
            return CGRect(x: rect.minX, y: rect.minY + dy, width: rect.width + dx, height: rect.height - dy)
        case .bottomLeft:
            return CGRect(x: rect.minX + dx, y: rect.minY, width: rect.width - dx, height: rect.height + dy)
        case .bottomRight:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width + dx, height: rect.height + dy)
        }
    }
}

private struct CropMask: View {
    var crop: CGRect
    var imageFrame: CGRect

    var body: some View {
        let hole = viewRect(for: crop, in: imageFrame)
        Canvas { context, _ in
            var path = Path(imageFrame)
            path.addRect(hole)
            context.fill(path, with: .color(.black.opacity(0.45)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }
}

private func suggestedCrop(width: Int, height: Int) -> CGRect {
    let aspect = CGFloat(width) / CGFloat(max(height, 1))
    if aspect > 1.15 {
        return CGRect(x: 0.03, y: 0.05, width: 0.32, height: 0.9)
    }
    return CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.92)
}

private func clamped(_ rect: CGRect) -> CGRect {
    var rect = rect
    rect.size.width = min(max(rect.width, 0.12), 1)
    rect.size.height = min(max(rect.height, 0.12), 1)
    if rect.width < 0 {
        rect.origin.x += rect.width
        rect.size.width = abs(rect.width)
    }
    if rect.height < 0 {
        rect.origin.y += rect.height
        rect.size.height = abs(rect.height)
    }
    rect.origin.x = min(max(0, rect.origin.x), 1 - rect.width)
    rect.origin.y = min(max(0, rect.origin.y), 1 - rect.height)
    return rect
}

private func aspectFit(_ imageSize: CGSize, in container: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else {
        return CGRect(origin: .zero, size: container)
    }
    let scale = min(container.width / imageSize.width, container.height / imageSize.height)
    let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let origin = CGPoint(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2)
    return CGRect(origin: origin, size: size)
}

private func viewRect(for crop: CGRect, in imageFrame: CGRect) -> CGRect {
    CGRect(
        x: imageFrame.minX + crop.minX * imageFrame.width,
        y: imageFrame.minY + crop.minY * imageFrame.height,
        width: crop.width * imageFrame.width,
        height: crop.height * imageFrame.height
    )
}

private func pixelRect(for crop: CGRect, width: Int, height: Int) -> CGRect {
    let rect = CGRect(
        x: crop.minX * CGFloat(width),
        y: crop.minY * CGFloat(height),
        width: crop.width * CGFloat(width),
        height: crop.height * CGFloat(height)
    ).integral
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    return rect.intersection(bounds)
}

private func cgImage(from data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func jpegData(from image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}

private func rotated(_ image: CGImage, quarters: Int) -> CGImage? {
    let turns = ((quarters % 4) + 4) % 4
    if turns == 0 { return image }
    let swap = turns % 2 == 1
    let width = swap ? image.height : image.width
    let height = swap ? image.width : image.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
    context.rotate(by: -CGFloat(turns) * .pi / 2)
    context.translateBy(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return context.makeImage()
}
