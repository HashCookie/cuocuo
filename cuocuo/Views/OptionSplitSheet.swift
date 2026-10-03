import CoreGraphics
import ImageIO
import SwiftUI

struct OptionSplitRequest: Identifiable {
    let id = UUID()
    let data: Data
}

struct OptionSplitSheet: View {
    let imageData: Data
    var onSave: ([String: Data]) -> Void
    var onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .working
    @State private var clips: [String: Data] = [:]
    @State private var manualIndex = 0
    @State private var previews: [String: CGImage] = [:]

    private let letters = ["A", "B", "C", "D"]

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .working:
                    ProgressView("正在分开四个选项图")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .review:
                    review
                case .manual:
                    QuestionCropView(
                        imageData: imageData,
                        purpose: .question,
                        remaining: 1,
                        titleText: "框出 \(letters[manualIndex]) 的图形",
                        confirmText: "这是 \(letters[manualIndex])",
                        onUse: { data in
                            clips[letters[manualIndex]] = data
                            if manualIndex == letters.count - 1 {
                                previews = images(from: clips)
                                phase = .review
                            } else {
                                manualIndex += 1
                            }
                        },
                        onUseThenRule: nil,
                        onSkip: onSkipAndClose,
                        onCancel: onSkipAndClose
                    )
                    .id(manualIndex)
                case .failed:
                    ContentUnavailableView {
                        Label("没能自动分开", systemImage: "square.grid.2x2")
                    } description: {
                        Text("这道图形题的四个选项没有对上。可以逐个框出 A、B、C、D。")
                    } actions: {
                        Button("逐个框") {
                            clips = [:]
                            manualIndex = 0
                            phase = .manual
                        }
                        .buttonStyle(.borderedProminent)
                        Button("先不用", action: onSkipAndClose)
                    }
                }
            }
            .navigationTitle(phase == .manual ? "框出 \(letters[manualIndex]) 的图形" : "选项图")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if phase != .manual {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("先不用", action: onSkipAndClose)
                    }
                }
            }
        }
        .task { await detect() }
    }

    private var review: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(letters, id: \.self) { letter in
                    VStack(spacing: 6) {
                        if let image = previews[letter] {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                        }
                        Text(letter)
                            .font(.headline)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            Button("就用这些") {
                onSave(clips)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("重新框") {
                clips = [:]
                manualIndex = 0
                phase = .manual
            }
            Spacer()
        }
    }

    private func detect() async {
        let found = await OptionFigureSplitter.split(imageData)
        if found.count == 4 {
            clips = found
            previews = images(from: found)
            phase = .review
        } else {
            phase = .failed
        }
    }

    private func images(from clips: [String: Data]) -> [String: CGImage] {
        var images: [String: CGImage] = [:]
        for (letter, data) in clips {
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                images[letter] = image
            }
        }
        return images
    }

    private func onSkipAndClose() {
        onSkip()
        dismiss()
    }
}

private enum Phase {
    case working
    case review
    case manual
    case failed
}
