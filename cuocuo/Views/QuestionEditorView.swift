import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct QuestionEditorView: View {
    let existing: WrongQuestion?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft: QuestionDraft
    @State private var customTag = ""
    @State private var captureKind: PageKind = .question
    @State private var showScanner = false
    @State private var showCamera = false
    @State private var importingFiles = false
    @State private var pendingImports = 0
    @State private var tasks: [UUID: Task<Void, Never>] = [:]
    @State private var didFinish = false
    @State private var isSaving = false
    @State private var showDiscard = false
    @State private var notice: EditorNotice?
    @State private var viewer: PageViewerRoute?

    init(existing: WrongQuestion?, defaultModule: ExamModule) {
        self.existing = existing
        if let existing {
            _draft = State(initialValue: QuestionDraft(question: existing))
        } else {
            _draft = State(initialValue: QuestionDraft(module: defaultModule))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                ownershipSection
                pagesSection(kind: .question)
                pagesSection(kind: .analysis)
                causeSection
                statusSection
                if isBusy {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在识别文字，完成后即可存储。")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "新建错题" : "编辑错题")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: askCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("存储", action: save)
                        .disabled(!draft.canSave || pendingImports > 0 || isSaving)
                }
            }
        }
        .interactiveDismissDisabled(draft.isDirty || isBusy)
        .onDisappear(perform: discardIfSheetClosed)
        .fileImporter(
            isPresented: $importingFiles,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                importURLs(urls, kind: captureKind)
            case .failure:
                notice = EditorNotice(title: "无法收录", message: "没有读到所选文件。")
            }
        }
        .adaptiveCover(isPresented: $showScanner) { scannerCover }
        .adaptiveCover(isPresented: $showCamera) { cameraCover }
        .adaptiveCover(item: $viewer) { route in
            PageViewer(title: route.title, paths: route.paths, index: route.index)
        }
        .confirmationDialog("放弃已录入的内容？", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("放弃", role: .destructive) {
                Task { await close(saved: false) }
            }
            Button("继续编辑", role: .cancel) {}
        }
        .alert(
            notice?.title ?? "",
            isPresented: Binding(
                get: { notice != nil },
                set: { if !$0 { notice = nil } }
            ),
            presenting: notice
        ) { current in
            if current.showsSettings {
                Button("前往设置") { CaptureAvailability.openSystemSettings() }
            }
            Button("好", role: .cancel) {}
        } message: { current in
            Text(current.message)
        }
    }

    private var isBusy: Bool {
        pendingImports > 0 || draft.isRecognizing
    }

    private var ownershipSection: some View {
        Section("归属") {
            Picker("模块", selection: $draft.module) {
                ForEach(ExamModule.allCases) { module in
                    Text(module.title).tag(module)
                }
            }
            .onChange(of: draft.module) { _, _ in
                draft.sanitizeSelection()
            }
            Picker("子题型", selection: subtypeSelection) {
                Text("不选择").tag("")
                ForEach(draft.module.subtypes, id: \.self) { subtype in
                    Text(subtype).tag(subtype)
                }
            }
        }
    }

    private var subtypeSelection: Binding<String> {
        Binding(
            get: { draft.subtype ?? "" },
            set: { draft.subtype = $0.isEmpty ? nil : $0 }
        )
    }

    private func pagesSection(kind: PageKind) -> some View {
        DraftPagesSection(
            kind: kind,
            draft: $draft,
            footerNotes: footerNotes(for: kind),
            onTap: { item in showPage(item, kind: kind) },
            onScan: { openScanner(for: kind) },
            onCamera: { openCamera(for: kind) },
            onFiles: {
                captureKind = kind
                importingFiles = true
            },
            onIngest: { ingestMany([$0], kind: kind) },
            onIngestFailed: {
                notice = EditorNotice(title: "无法收录", message: "这张图片没有读出来。")
            },
            onRerecognize: rerecognize,
            onRemove: { draft.remove(pageID: $0) },
            onMove: { id, earlier in draft.move(pageID: id, earlier: earlier) },
            onFocusedEdit: {
                if kind == .question {
                    draft.questionTextEdited = true
                } else {
                    draft.analysisTextEdited = true
                }
            }
        )
    }

    private func footerNotes(for kind: PageKind) -> [String] {
        var notes = ["图片会原样保存，文字用于搜索。"]
        if kind == .question, !draft.hasQuestionPage {
            notes.append("题目至少需要一页。")
        }
        if kind == .analysis, draft.hasQuestionPage, !draft.hasAnalysisMaterial {
            notes.append("错因至少需要一页，或写上一句错因。")
        }
        if kind == .question, let hint = CaptureAvailability.platformHint {
            notes.append(hint)
        }
        return notes
    }

    private var causeSection: some View {
        Section {
            ForEach(CauseTagLibrary.common, id: \.self) { tag in
                Toggle(tag, isOn: tagBinding(tag))
            }
            ForEach(CauseTagLibrary.specific(draft.module), id: \.self) { tag in
                Toggle(tag, isOn: tagBinding(tag))
            }
            ForEach(customTags, id: \.self) { tag in
                HStack {
                    Text(tag)
                    Spacer()
                    Button("移除") {
                        draft.causeTags.removeAll { $0 == tag }
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("自定义错因，最多 12 个字", text: $customTag)
                    .onSubmit(addCustomTag)
                    .onChange(of: customTag) { _, newValue in
                        if newValue.count > 12 {
                            customTag = String(newValue.prefix(12))
                        }
                    }
                Button("添加", action: addCustomTag)
                    .disabled(customTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("错因标签")
        } footer: {
            Text("标签用来筛选，不代替错因原文。")
        }
    }

    private var customTags: [String] {
        draft.causeTags.filter { !CauseTagLibrary.isBuiltIn($0) }
    }

    private var statusSection: some View {
        Section("状态") {
            Picker("掌握状态", selection: $draft.mastery) {
                ForEach(Mastery.allCases) { mastery in
                    Text(mastery.title).tag(mastery)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func tagBinding(_ tag: String) -> Binding<Bool> {
        Binding(
            get: { draft.causeTags.contains(tag) },
            set: { isOn in
                if isOn {
                    if !draft.causeTags.contains(tag) {
                        draft.causeTags.append(tag)
                    }
                } else {
                    draft.causeTags.removeAll { $0 == tag }
                }
            }
        )
    }

    private func addCustomTag() {
        let trimmed = String(customTag.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12))
        customTag = ""
        guard !trimmed.isEmpty, !draft.causeTags.contains(trimmed) else { return }
        draft.causeTags.append(trimmed)
    }

    private func showPage(_ item: PageStrip.Item, kind: PageKind) {
        let pages = draft.pages
            .filter { $0.kind == kind }
            .sorted { $0.order < $1.order }
        guard let index = pages.firstIndex(where: { $0.id == item.id }) else { return }
        viewer = PageViewerRoute(title: kind.title, paths: pages.map(\.relativePath), index: index)
    }

    private func openScanner(for kind: PageKind) {
        captureKind = kind
        guard CaptureAvailability.documentScannerSupported else {
            notice = EditorNotice(title: "无法扫描", message: "当前设备不能扫描文稿，请改用相册或文件。")
            return
        }
        Task {
            if await authorizeCamera() {
                showScanner = true
            }
        }
    }

    private func openCamera(for kind: PageKind) {
        captureKind = kind
        guard CaptureAvailability.cameraAvailable else {
            notice = EditorNotice(title: "无法拍照", message: "当前设备没有相机，请改用相册或文件。")
            return
        }
        Task {
            if await authorizeCamera() {
                showCamera = true
            }
        }
    }

    private func authorizeCamera() async -> Bool {
        #if os(iOS)
        let result = await CaptureAvailability.authorizeCamera()
        if result == .denied {
            notice = EditorNotice(
                title: "需要相机权限",
                message: "可以在系统设置中打开相机，或改用相册和文件。",
                showsSettings: true
            )
            return false
        }
        return true
        #else
        return false
        #endif
    }

    private func importURLs(_ urls: [URL], kind: PageKind) {
        var didFail = false
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            if let data = try? Data(contentsOf: url) {
                ingestMany([data], kind: kind)
            } else {
                didFail = true
            }
        }
        if didFail {
            notice = EditorNotice(title: "无法收录", message: "有图片没有读出来。")
        }
    }

    private func ingestMany(_ datas: [Data], kind: PageKind) {
        let questionID = draft.id
        let start = (draft.pages.filter { $0.kind == kind }.map(\.order).max() ?? -1) + 1
        for (offset, data) in datas.enumerated() where !data.isEmpty {
            let pageID = UUID()
            let order = start + offset
            pendingImports += 1
            let task = Task { @MainActor in
                defer { pendingImports -= 1 }
                let jpeg = await Task.detached(priority: .userInitiated) {
                    ImageStore.normalizedJPEG(from: data)
                }.value
                if Task.isCancelled { return }
                guard let jpeg else {
                    notice = EditorNotice(title: "无法收录", message: "这张图片没有保存下来。")
                    return
                }
                let path: String
                do {
                    path = try ImageStore.write(jpeg, questionID: questionID, pageID: pageID)
                } catch {
                    notice = EditorNotice(title: "无法收录", message: "这张图片没有保存下来。")
                    return
                }
                if Task.isCancelled { return }
                draft.pages.append(
                    DraftPage(
                        id: pageID,
                        kind: kind,
                        order: order,
                        relativePath: path,
                        recognizedText: "",
                        isRecognizing: true,
                        recognitionFailed: false
                    )
                )
                let text = await TextRecognizer.recognizeText(in: jpeg)
                if Task.isCancelled { return }
                draft.applyRecognition(pageID: pageID, text: text, appendIfEdited: true)
            }
            tasks[pageID] = task
        }
    }

    private func rerecognize(_ pageID: UUID) {
        guard let page = draft.pages.first(where: { $0.id == pageID }) else { return }
        tasks[pageID]?.cancel()
        draft.markRecognizing(pageID: pageID)
        let path = page.relativePath
        let task = Task { @MainActor in
            let data = await Task.detached(priority: .userInitiated) {
                ImageStore.fileData(relativePath: path)
            }.value
            if Task.isCancelled { return }
            let text: String?
            if let data {
                text = await TextRecognizer.recognizeText(in: data)
            } else {
                text = nil
            }
            if Task.isCancelled { return }
            draft.applyRecognition(pageID: pageID, text: text, appendIfEdited: false)
        }
        tasks[pageID] = task
    }

    private func askCancel() {
        if draft.isDirty || isBusy {
            showDiscard = true
        } else {
            Task { await close(saved: false) }
        }
    }

    private func save() {
        guard draft.canSave, pendingImports == 0, !isSaving else { return }
        isSaving = true
        do {
            try QuestionStore.save(draft: draft, existing: existing, in: modelContext)
        } catch {
            isSaving = false
            notice = EditorNotice(title: "没有存下来", message: "请再试一次。")
            return
        }
        Task { await close(saved: true) }
    }

    private func close(saved: Bool) async {
        guard !didFinish else { return }
        didFinish = true
        let running = Array(tasks.values)
        for task in running { task.cancel() }
        for task in running { await task.value }
        if !saved {
            ImageStore.cleanup(questionID: draft.id, keep: draft.originalPaths)
        }
        dismiss()
    }

    /// 扫一扫、拍照和选文件会盖住这张表单。那种消失不能把已经扫进来的页清掉。
    private func discardIfSheetClosed() {
        guard !didFinish else { return }
        guard !showScanner, !showCamera, viewer == nil, !importingFiles else { return }
        didFinish = true
        for task in tasks.values { task.cancel() }
        ImageStore.cleanup(questionID: draft.id, keep: draft.originalPaths)
    }

    @ViewBuilder
    private var scannerCover: some View {
        #if os(iOS)
        DocumentScannerView { images in
            showScanner = false
            ingestMany(images, kind: captureKind)
        } onCancel: {
            showScanner = false
        }
        .ignoresSafeArea()
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var cameraCover: some View {
        #if os(iOS)
        CameraPicker { data in
            showCamera = false
            if data.isEmpty {
                notice = EditorNotice(title: "无法拍照", message: "没有得到照片，请再试一次，或改用相册。")
            } else {
                ingestMany([data], kind: captureKind)
            }
        } onCancel: {
            showCamera = false
        }
        .ignoresSafeArea()
        #else
        EmptyView()
        #endif
    }
}

struct EditorNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var showsSettings = false
}
