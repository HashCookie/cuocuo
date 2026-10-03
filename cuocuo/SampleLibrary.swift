import CoreGraphics
import CoreText
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

enum SampleLibrary {
    static let argument = "-seed-sample"

    @MainActor
    static func installIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains(argument) else { return }
        let existing = (try? context.fetch(FetchDescriptor<WrongQuestion>())) ?? []
        for question in existing {
            ImageStore.deleteFolder(questionID: question.id)
            context.delete(question)
        }
        try? context.save()

        let quantitative = makeQuestion(
            in: context,
            module: .quantitative,
            subtype: "数学运算",
            questionText: "一项工程，甲单独做 10 天，乙单独做 15 天。两人合作几天完成？",
            analysisText: "把工程看成 1。甲每天 1/10，乙每天 1/15，合作效率 1/6，所以 6 天。",
            correct: "B",
            createdAt: Date().addingTimeInterval(-86_400),
            imageTitle: "工程问题",
            imageLines: ["甲 10 天，乙 15 天", "合作几天完成？", "A. 4天  B. 6天", "C. 8天  D. 12天"]
        )
        let figure = makeQuestion(
            in: context,
            module: .judgment,
            subtype: "图形推理",
            questionText: "",
            analysisText: "规律：黑色方块每次顺时针走一格。",
            correct: "C",
            createdAt: Date().addingTimeInterval(-3_600),
            imageTitle: "图形推理",
            imageLines: ["选出填入问号处的图形", "A  B  C  D"]
        )
        figure.choiceClipLetters = ["A", "B", "C", "D"]
        figure.choiceClipPaths = ["A", "B", "C", "D"].map { letter in
            let data = card(title: letter, lines: ["选项 \(letter)"], red: 0.95, green: 0.95, blue: 0.9)
            return (try? ImageStore.writeNamed(data, questionID: figure.id, name: "choice-\(letter).jpg")) ?? ""
        }
        let later = makeQuestion(
            in: context,
            module: .verbal,
            subtype: "片段阅读",
            questionText: "这段文字的主旨是作者强调实践。",
            analysisText: "主旨在最后一句，不在举例。",
            correct: "A",
            createdAt: Date().addingTimeInterval(-172_800),
            imageTitle: "主旨题",
            imageLines: ["作者强调的是？", "A. 实践  B. 理论"]
        )
        later.nextReviewAt = Date().addingTimeInterval(86_400 * 5)
        try? context.save()
    }

    @MainActor
    private static func makeQuestion(
        in context: ModelContext,
        module: ExamModule,
        subtype: String,
        questionText: String,
        analysisText: String,
        correct: String,
        createdAt: Date,
        imageTitle: String,
        imageLines: [String]
    ) -> WrongQuestion {
        let question = WrongQuestion(
            id: UUID(),
            module: module,
            subtype: subtype,
            questionText: questionText,
            analysisText: analysisText,
            causeTags: [],
            correctChoice: correct,
            mastery: .unmastered,
            nextReviewAt: createdAt,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        context.insert(question)
        let data = card(title: imageTitle, lines: imageLines, red: 1, green: 0.98, blue: 0.9)
        if let path = try? ImageStore.write(data, questionID: question.id, pageID: UUID()) {
            let page = ScanPage(id: UUID(), kind: .question, order: 0, relativePath: path, recognizedText: questionText)
            page.question = question
            context.insert(page)
        }
        return question
    }

    private static func card(title: String, lines: [String], red: CGFloat, green: CGFloat, blue: CGFloat) -> Data {
        let width = 800
        let height = 480
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Data() }
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0.1, alpha: 1))
        draw(title, in: context, rect: CGRect(x: 32, y: height - 90, width: width - 64, height: 48), size: 32)
        for (index, line) in lines.enumerated() {
            let y = height - 170 - index * 56
            draw(line, in: context, rect: CGRect(x: 32, y: y, width: width - 64, height: 44), size: 26)
        }
        guard let image = context.makeImage() else { return Data() }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private static func draw(_ text: String, in context: CGContext, rect: CGRect, size: CGFloat) {
        let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, size, nil)
        let attributes = [kCTFontAttributeName: font] as CFDictionary
        let attributed = CFAttributedStringCreate(nil, text as CFString, attributes)!
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: rect.minX, y: rect.minY)
        CTLineDraw(line, context)
    }
}
