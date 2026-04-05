import Testing
import Foundation
import SwiftData
@testable import Memora

@MainActor
struct KnowledgeQueryServiceTests {

    // MARK: - Helpers

    private func makeContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: AudioFile.self, Transcript.self, MeetingMemo.self, Project.self, KnowledgeChunk.self, MemoryProfile.self, MemoryFact.self, TodoItem.self, configurations: config)
        return ModelContext(container)
    }

    private func makeService(context: ModelContext, privacyMode: String = "standard") -> KnowledgeQueryService {
        KnowledgeQueryService(modelContext: context, memoryPrivacyMode: privacyMode)
    }

    // MARK: - File Scope: buildContext returns correct scopeTitle

    @Test("file scope: buildContext がファイルタイトルを scopeTitle に含む")
    func fileScopeScopeTitle() {
        let ctx = makeContext()
        let fileID = UUID()
        let file = AudioFile(title: "定例MTG 4月", audioURL: "/tmp/test.m4a", projectID: nil)
        file.id = fileID
        ctx.insert(file)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .file(fileId: fileID))

        #expect(pack.scopeTitle == "定例MTG 4月")
    }

    @Test("file scope: 存在しないIDでは空パックが返る")
    func fileScopeMissing() {
        let ctx = makeContext()
        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .file(fileId: UUID()))

        #expect(pack.scopeTitle == "このファイル")
        #expect(pack.promptContext.isEmpty)
        #expect(pack.sourceBadges.isEmpty)
        #expect(pack.citations.isEmpty)
    }

    // MARK: - File Scope: context includes transcript, summary, memo

    @Test("file scope: transcript / summary / memo が context に含まれる")
    func fileScopeContextSources() {
        let ctx = makeContext()
        let fileID = UUID()
        let file = AudioFile(title: "企画会議", audioURL: "/tmp/test.m4a")
        file.id = fileID
        file.summary = "来月のリリース予定を確認"
        ctx.insert(file)

        let transcript = Transcript(audioFileID: fileID, text: "来月リリースを目指します")
        ctx.insert(transcript)

        let memo = MeetingMemo(audioFileID: fileID, markdown: "決定: リリース日 5/1", plainTextCache: "決定: リリース日 5/1")
        ctx.insert(memo)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .file(fileId: fileID))

        let context = pack.promptContext
        #expect(context.contains("来月リリースを目指します"))
        #expect(context.contains("来月のリリース予定を確認"))
        #expect(context.contains("決定: リリース日 5/1"))
    }

    // MARK: - File Scope: sourceBadges reflect context types

    @Test("file scope: sourceBadges に含まれる type が正しい")
    func fileScopeBadges() {
        let ctx = makeContext()
        let fileID = UUID()
        let file = AudioFile(title: "テスト", audioURL: "/tmp/test.m4a")
        file.id = fileID
        file.summary = "要約テキスト"
        ctx.insert(file)

        let transcript = Transcript(audioFileID: fileID, text: "文字起こしテキスト")
        ctx.insert(transcript)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .file(fileId: fileID))

        let badgeLabels = pack.sourceBadges.map(\.label)
        #expect(badgeLabels.contains("Transcript"))
        #expect(badgeLabels.contains("Summary"))
    }

    // MARK: - File Scope: citations reflect context sources

    @Test("file scope: citations に context source が反映される")
    func fileScopeCitations() {
        let ctx = makeContext()
        let fileID = UUID()
        let file = AudioFile(title: "営業会議", audioURL: "/tmp/test.m4a")
        file.id = fileID
        file.summary = "Q2 目標を確認"
        ctx.insert(file)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .file(fileId: fileID))

        #expect(!pack.citations.isEmpty)
        let citation = pack.citations.first!
        #expect(citation.sourceLabel == "Summary")
        #expect(citation.title.contains("営業会議"))
    }

    // MARK: - Project Scope: buildContext with KnowledgeChunks

    @Test("project scope: KnowledgeChunk が context に反映される")
    func projectScopeWithChunks() {
        let ctx = makeContext()
        let projectID = UUID()
        let project = Project(title: "新機能開発")
        project.id = projectID
        ctx.insert(project)

        let chunk = KnowledgeChunk(
            scopeType: .project,
            scopeID: projectID,
            sourceType: .summary,
            text: "バージョン2.0の設計完了",
            keywords: ["設計", "v2"],
            rankHint: 10.0
        )
        ctx.insert(chunk)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .project(projectId: projectID))

        #expect(pack.scopeTitle == "新機能開発")
        #expect(pack.promptContext.contains("バージョン2.0の設計完了"))
    }

    @Test("project scope: KnowledgeChunk がない場合 direct fallback が動く")
    func projectScopeFallback() {
        let ctx = makeContext()
        let projectID = UUID()
        let project = Project(title: "バグ修正")
        project.id = projectID
        ctx.insert(project)

        let file = AudioFile(title: "障害対応MTG", audioURL: "/tmp/test.m4a", projectID: projectID)
        file.summary = "原因は設定ミス"
        ctx.insert(file)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .project(projectId: projectID))

        #expect(pack.scopeTitle == "バグ修正")
        #expect(pack.promptContext.contains("原因は設定ミス"))
    }

    // MARK: - Global Scope: buildContext with KnowledgeChunks

    @Test("global scope: KnowledgeChunk が context に反映される")
    func globalScopeWithChunks() {
        let ctx = makeContext()

        let chunk = KnowledgeChunk(
            scopeType: .global,
            sourceType: .summary,
            text: "全体進捗: 80%完了",
            keywords: ["進捗"],
            rankHint: 5.0
        )
        ctx.insert(chunk)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .global)

        #expect(pack.scopeTitle == "Memora 全体")
        #expect(pack.promptContext.contains("全体進捗: 80%完了"))
    }

    // MARK: - makePrompt includes context and user message

    @Test("makePrompt が context と user message を含む")
    func makePromptContainsContextAndMessage() {
        let ctx = makeContext()
        let service = makeService(context: ctx)

        let pack = KnowledgeQueryService.ContextPack(
            scopeTitle: "テストスコープ",
            promptContext: "テストコンテキスト内容",
            sourceBadges: [],
            citations: [],
            instructionHints: []
        )

        let prompt = service.makePrompt(userMessage: "進捗どう？", contextPack: pack)

        #expect(prompt.contains("テストスコープ"))
        #expect(prompt.contains("テストコンテキスト内容"))
        #expect(prompt.contains("進捗どう？"))
    }

    @Test("makePrompt: context が空の時はフォールバック文言が入る")
    func makePromptEmptyContext() {
        let ctx = makeContext()
        let service = makeService(context: ctx)

        let pack = KnowledgeQueryService.ContextPack(
            scopeTitle: "テスト",
            promptContext: "",
            sourceBadges: [],
            citations: [],
            instructionHints: []
        )

        let prompt = service.makePrompt(userMessage: "教えて", contextPack: pack)
        #expect(prompt.contains("コンテキストはまだありません"))
    }

    // MARK: - Scope difference: file vs project vs global produce different context

    @Test("同じデータで file/project/global の context が異なる")
    func scopeDifference() {
        let ctx = makeContext()
        let projectID = UUID()
        let fileID = UUID()

        let project = Project(title: "リサーチ")
        project.id = projectID
        ctx.insert(project)

        let file = AudioFile(title: "ユーザーインタビュー", audioURL: "/tmp/test.m4a", projectID: projectID)
        file.id = fileID
        file.summary = "ペルソナAの課題: 予定管理が煩雑"
        ctx.insert(file)

        // Global chunk
        let globalChunk = KnowledgeChunk(
            scopeType: .global,
            sourceType: .todo,
            text: "全体未完了タスク: 5件",
            rankHint: 3.0
        )
        ctx.insert(globalChunk)

        // Project chunk
        let projectChunk = KnowledgeChunk(
            scopeType: .project,
            scopeID: projectID,
            sourceType: .summary,
            text: "プロジェクト概要: UX改善",
            rankHint: 8.0
        )
        ctx.insert(projectChunk)

        try? ctx.save()

        let service = makeService(context: ctx)

        let filePack = service.buildContext(for: .file(fileId: fileID))
        let projectPack = service.buildContext(for: .project(projectId: projectID))
        let globalPack = service.buildContext(for: .global)

        // file scope: direct file data (summary), no chunk
        #expect(filePack.scopeTitle == "ユーザーインタビュー")
        #expect(filePack.promptContext.contains("ペルソナAの課題"))

        // project scope: project chunk is picked up
        #expect(projectPack.scopeTitle == "リサーチ")
        #expect(projectPack.promptContext.contains("UX改善"))

        // global scope: global chunk is picked up
        #expect(globalPack.scopeTitle == "Memora 全体")
        #expect(globalPack.promptContext.contains("全体未完了タスク"))
    }

    // MARK: - Photo OCR chunk in file scope

    @Test("file scope: photoOCR chunk が context に含まれる")
    func fileScopePhotoOCR() {
        let ctx = makeContext()
        let fileID = UUID()
        let file = AudioFile(title: "ホワイトボード会議", audioURL: "/tmp/test.m4a")
        file.id = fileID
        ctx.insert(file)

        let ocrChunk = KnowledgeChunk(
            scopeType: .file,
            scopeID: fileID,
            sourceType: .photoOCR,
            text: "ホワイトボード: Sprint Goal = リリース準備",
            keywords: ["sprint", "リリース"],
            rankHint: 7.0
        )
        ctx.insert(ocrChunk)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .file(fileId: fileID))

        #expect(pack.promptContext.contains("ホワイトボード: Sprint Goal = リリース準備"))
        let badgeLabels = pack.sourceBadges.map(\.label)
        #expect(badgeLabels.contains("OCR"))
    }

    // MARK: - Privacy mode: off suppresses memory sources

    @Test("memoryPrivacyMode off: instructionHints に memory オフ指示が含まれる")
    func privacyModeOff() {
        let ctx = makeContext()
        let service = makeService(context: ctx, privacyMode: "off")

        let pack = service.buildContext(for: .global)

        #expect(pack.instructionHints.contains(where: { $0.contains("memory 設定が完全オフ") }))
    }

    // MARK: - Rank ordering: higher rankHint chunks come first

    @Test("project scope: rankHint が高い chunk が優先される")
    func rankOrdering() {
        let ctx = makeContext()
        let projectID = UUID()
        let project = Project(title: "優先度テスト")
        project.id = projectID
        ctx.insert(project)

        let lowChunk = KnowledgeChunk(
            scopeType: .project,
            scopeID: projectID,
            sourceType: .transcript,
            text: "低重要度テキスト",
            rankHint: 1.0
        )
        let highChunk = KnowledgeChunk(
            scopeType: .project,
            scopeID: projectID,
            sourceType: .summary,
            text: "高重要度テキスト",
            rankHint: 10.0
        )
        ctx.insert(lowChunk)
        ctx.insert(highChunk)
        try? ctx.save()

        let service = makeService(context: ctx)
        let pack = service.buildContext(for: .project(projectId: projectID))

        let context = pack.promptContext
        let highRange = context.range(of: "高重要度テキスト")
        let lowRange = context.range(of: "低重要度テキスト")

        if let highRange, let lowRange {
            #expect(highRange.lowerBound < lowRange.lowerBound)
        }
    }
}
