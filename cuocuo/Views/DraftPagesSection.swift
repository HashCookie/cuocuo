import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct DraftPagesSection: View {
    let kind: PageKind
    @Binding var draft: QuestionDraft
    var footerNotes: [String]
    var onTap: (PageStrip.Item) -> Void
    var onScan: () -> Void
    var onCamera: () -> Void
    var onFiles: () -> Void
    var onIngest: (Data) -> Void
    var onIngestFailed: () -> Void
    var onRerecognize: (UUID) -> Void
    var onRemove: (UUID) -> Void
    var onMove: (UUID, Bool) -> Void
    var onFocusedEdit: () -> Void

    @State private var photoItems: [PhotosPickerItem] = []
    @FocusState private var textFocused: Bool

    private var text: Binding<String> {
        Binding(
            get: { kind == .question ? draft.questionText : draft.analysisText },
            set: { newValue in
                if kind == .question {
                    draft.questionText = newValue
                } else {
                    draft.analysisText = newValue
                }
            }
        )
    }

    var body: some View {
        Section {
            if !stripItems.isEmpty {
                PageStrip(
                    items: stripItems,
                    onTap: onTap,
                    onMoveEarlier: { item in onMove(item.id, true) },
                    onMoveLater: { item in onMove(item.id, false) },
                    onRecognize: { item in onRerecognize(item.id) },
                    onDelete: { item in onRemove(item.id) }
                )
                .frame(minHeight: 112)
            }
            if CaptureAvailability.showsDocumentScanner {
                Button(action: onScan) {
                    Label("扫描文稿", systemImage: "document.viewfinder")
                }
            }
            if CaptureAvailability.showsCamera {
                Button(action: onCamera) {
                    Label("拍照", systemImage: "camera")
                }
            }
            PhotosPicker(selection: $photoItems, maxSelectionCount: 12, matching: .images) {
                Label("相册", systemImage: "photo.on.rectangle")
            }
            Button(action: onFiles) {
                Label("文件", systemImage: "folder")
            }
            TextEditor(text: text)
                .focused($textFocused)
                .frame(minHeight: 140)
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        } header: {
            Text(kind.title)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(footerNotes, id: \.self) { note in
                    Text(note)
                }
            }
        }
        .onChange(of: text.wrappedValue) { _, _ in
            // 识别结果会直接改草稿。只有光标在文字栏里，才算用户自己改过。
            if textFocused {
                onFocusedEdit()
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            let batch = items
            photoItems = []
            Task { await load(batch) }
        }
    }

    private var placeholder: String {
        switch kind {
        case .question:
            "识别出的题目文字会出现在这里，也可以直接修改。"
        case .analysis:
            "识别出的错因会出现在这里，也可以直接写下错因。"
        }
    }

    private var stripItems: [PageStrip.Item] {
        draft.pages
            .filter { $0.kind == kind }
            .sorted { $0.order < $1.order }
            .enumerated()
            .map { index, page in
                PageStrip.Item(
                    id: page.id,
                    path: page.relativePath,
                    isRecognizing: page.isRecognizing,
                    failed: page.recognitionFailed,
                    label: "\(kind.title)第 \(index + 1) 页"
                )
            }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let picked = try? await item.loadTransferable(type: PickedImage.self) {
                onIngest(picked.data)
            } else {
                onIngestFailed()
            }
        }
    }
}

private struct PickedImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PickedImage(data: data)
        }
    }
}
