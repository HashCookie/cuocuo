import Foundation
import SwiftData
import SwiftUI

struct QuestionDetailView: View {
    @Bindable var question: WrongQuestion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editing = false
    @State private var pendingDelete: WrongQuestion?
    @State private var viewer: PageViewerRoute?

    var body: some View {
        List {
            Section {
                LabeledContent("模块", value: question.module.title)
                if let subtype = question.subtype, !subtype.isEmpty {
                    LabeledContent("子题型", value: subtype)
                }
                LabeledContent("收录日期", value: Self.day(question.createdAt))
                Toggle("已掌握", isOn: masteredBinding)
            }
            Section("题目") {
                pages(question.questionPages, title: "题目")
                Text(question.questionText.isEmpty ? "未识别出文字" : question.questionText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("错因") {
                pages(question.analysisPages, title: "错因")
                Text(question.analysisText.isEmpty ? "未识别出文字" : question.analysisText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !question.causeTags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("错因标签")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(question.causeTags.joined(separator: "、"))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("错题")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = true
                } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    pendingDelete = question
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $editing) {
            QuestionEditorView(existing: question, defaultModule: question.module)
        }
        .adaptiveCover(item: $viewer) { route in
            PageViewer(title: route.title, paths: route.paths, index: route.index)
        }
        .deleteQuestionDialog(pending: $pendingDelete) {
            dismiss()
        }
    }

    @ViewBuilder
    private func pages(_ pages: [ScanPage], title: String) -> some View {
        if !pages.isEmpty {
            PageStrip(items: pages.enumerated().map { index, page in
                PageStrip.Item(
                    id: page.id,
                    path: page.relativePath,
                    isRecognizing: false,
                    failed: false,
                    label: "\(title)第 \(index + 1) 页"
                )
            }) { item in
                guard let index = pages.firstIndex(where: { $0.id == item.id }) else { return }
                viewer = PageViewerRoute(
                    title: title,
                    paths: pages.map(\.relativePath),
                    index: index
                )
            }
            .frame(minHeight: 112)
        }
    }

    private var masteredBinding: Binding<Bool> {
        Binding(
            get: { question.mastery == .mastered },
            set: { isOn in
                try? QuestionStore.setMastered(isOn, question: question, in: modelContext)
            }
        )
    }

    private static func day(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .year()
                .month(.defaultDigits)
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}
