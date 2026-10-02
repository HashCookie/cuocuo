import SwiftUI

struct PageStrip: View {
    struct Item: Identifiable {
        let id: UUID
        let path: String
        let isRecognizing: Bool
        let failed: Bool
        let label: String
    }

    let items: [Item]
    var onTap: (Item) -> Void
    var onMoveEarlier: ((Item) -> Void)?
    var onMoveLater: ((Item) -> Void)?
    var onRecognize: ((Item) -> Void)?
    var onDelete: ((Item) -> Void)?

    private var hasMenu: Bool {
        onMoveEarlier != nil || onMoveLater != nil || onRecognize != nil || onDelete != nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    thumbnail(item, index: index)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func thumbnail(_ item: Item, index: Int) -> some View {
        let button = Button {
            onTap(item)
        } label: {
            FileImage(relativePath: item.path, maxPixel: 240, contentMode: .fill)
                .frame(width: 72, height: 96)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.quaternary)
                }
                .overlay(alignment: .bottomTrailing) {
                    status(for: item)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)

        if hasMenu {
            button.contextMenu {
                if let onMoveEarlier {
                    Button {
                        onMoveEarlier(item)
                    } label: {
                        Label("前移", systemImage: "arrow.left")
                    }
                    .disabled(index == 0)
                }
                if let onMoveLater {
                    Button {
                        onMoveLater(item)
                    } label: {
                        Label("后移", systemImage: "arrow.right")
                    }
                    .disabled(index == items.count - 1)
                }
                if let onRecognize {
                    Button {
                        onRecognize(item)
                    } label: {
                        Label("重新识别", systemImage: "text.viewfinder")
                    }
                    .disabled(item.isRecognizing)
                }
                if let onDelete {
                    Divider()
                    Button(role: .destructive) {
                        onDelete(item)
                    } label: {
                        Label("删除这一页", systemImage: "trash")
                    }
                }
            }
        } else {
            button
        }
    }

    @ViewBuilder
    private func status(for item: Item) -> some View {
        if item.isRecognizing {
            ProgressView()
                .controlSize(.small)
                .padding(6)
                .accessibilityLabel("正在识别")
        } else if item.failed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(6)
                .accessibilityLabel("没有识别出文字")
        }
    }
}
