import SwiftUI

extension View {
    @ViewBuilder
    func adaptiveCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, content: content)
        #else
        fullScreenCover(item: item, content: content)
        #endif
    }

    @ViewBuilder
    func adaptiveCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, content: content)
        #else
        fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}

struct PageViewerRoute: Identifiable {
    let id = UUID()
    let title: String
    let paths: [String]
    let index: Int
}

struct PageViewer: View {
    let title: String
    let paths: [String]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if paths.indices.contains(index) {
                    ZoomableImage(relativePath: paths[index])
                        .id(paths[index])
                }
                if paths.count > 1 {
                    HStack {
                        Button {
                            index = max(0, index - 1)
                        } label: {
                            Label("上一页", systemImage: "chevron.left")
                        }
                        .disabled(index == 0)
                        Spacer()
                        Text("\(index + 1) / \(paths.count)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            index = min(paths.count - 1, index + 1)
                        } label: {
                            Label("下一页", systemImage: "chevron.right")
                        }
                        .disabled(index == paths.count - 1)
                    }
                    .labelStyle(.titleAndIcon)
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct ZoomableImage: View {
    let relativePath: String
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                FileImage(relativePath: relativePath, maxPixel: 2000, contentMode: .fit)
                    .frame(width: geometry.size.width * scale)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .gesture(magnify)
        .onTapGesture(count: 2) {
            baseScale = baseScale > 1 ? 1 : 2.5
            scale = baseScale
        }
        .accessibilityHint("双指张开可以放大，双击可以在原大和放大之间切换")
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(baseScale * value.magnification, 1), 5)
            }
            .onEnded { value in
                baseScale = min(max(baseScale * value.magnification, 1), 5)
                scale = baseScale
            }
    }
}
