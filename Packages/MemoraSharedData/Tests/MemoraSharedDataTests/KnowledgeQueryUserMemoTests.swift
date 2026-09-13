import Testing
import Foundation
import SwiftData
import MemoraSharedCore
import MemoraSharedSchema
@testable import MemoraSharedAskAI

// R14: RN が保存するユーザーメモ（ホストの Documents/JSON メモストア由来）を
// file スコープの Ask AI コンテキストへ含める純ロジックのテスト。
// ホスト側のストア読み取り（MemoraNativeMemoRegistry）は MemoraRN ターゲットにあり
// xcodebuild なしでは実行できないため、ここでは KnowledgeQueryCore へ渡された
// userMemo がコンテキスト/プロンプトへ正しく現れることと、
// メモ無し・メモ空・file 以外のスコープでは何も追加されないことを検証する。
@MainActor
struct KnowledgeQueryUserMemoTests {

  private func makeModelContext() throws -> ModelContext {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: configuration
    )
    return ModelContext(container)
  }

  private func makeCore(context: ModelContext) -> KnowledgeQueryCore {
    // memory は off にして、メモリソースがテスト結果へ混ざらないようにする。
    KnowledgeQueryCore(
      modelContext: context,
      memoryPrivacy: .init(mode: "off", disabledFactIDs: [])
    )
  }

  @discardableResult
  private func insertFile(title: String, into context: ModelContext) throws -> AudioFile {
    let file = AudioFile(title: title, audioURL: "/tmp/r14-test.m4a")
    context.insert(file)
    try context.save()
    return file
  }

  @Test("file スコープではユーザーメモが明示ラベル付きでコンテキストへ含まれる")
  func userMemoAppearsInFileScopeContext() throws {
    let context = try makeModelContext()
    let file = try insertFile(title: "Growth 定例", into: context)
    let core = makeCore(context: context)

    let pack = core.buildContext(
      for: .file(fileId: file.id),
      query: "次のリリース日はいつですか？",
      userMemo: "決定事項: リリース日を9月12日とする。"
    )

    #expect(pack.promptContext.contains("[Growth 定例 / ユーザーメモ]"))
    #expect(pack.promptContext.contains("決定事項: リリース日を9月12日とする。"))
    #expect(pack.citations.contains { $0.sourceType == "user-memo" })
    #expect(pack.citations.contains { $0.title == "Growth 定例 / ユーザーメモ" })
  }

  @Test("ユーザーメモのみの状態でも transcript フォールバックは従来どおり含まれる")
  func transcriptFallbackIsNotSuppressedByUserMemo() throws {
    let context = try makeModelContext()
    let file = try insertFile(title: "Weekly Review", into: context)
    let transcript = Transcript(audioFileID: file.id, text: "議題: 週次レビューと来週の予定。")
    transcript.audioFile = file
    context.insert(transcript)
    try context.save()
    let core = makeCore(context: context)

    let pack = core.buildContext(
      for: .file(fileId: file.id),
      query: "来週の予定は？",
      userMemo: "メモ: 次回は水曜に開催。"
    )

    #expect(pack.promptContext.contains("[Weekly Review / ユーザーメモ]"))
    #expect(pack.promptContext.contains("メモ: 次回は水曜に開催。"))
    #expect(pack.promptContext.contains("議題: 週次レビューと来週の予定。"))
  }

  @Test("ユーザーメモが無い・空の場合は従来どおり追加されない")
  func noUserMemoWhenNilOrEmpty() throws {
    let context = try makeModelContext()
    let file = try insertFile(title: "Growth 定例", into: context)
    let core = makeCore(context: context)

    let withoutMemo = core.buildContext(for: .file(fileId: file.id), query: "決定事項は？")
    let emptyMemo = core.buildContext(
      for: .file(fileId: file.id),
      query: "決定事項は？",
      userMemo: "   "
    )

    #expect(!withoutMemo.promptContext.contains("ユーザーメモ"))
    #expect(withoutMemo.citations.allSatisfy { $0.sourceType != "user-memo" })
    #expect(!emptyMemo.promptContext.contains("ユーザーメモ"))
  }

  @Test("ユーザーメモは file スコープ以外ではコンテキストへ追加されない")
  func userMemoIgnoredOutsideFileScope() throws {
    let context = try makeModelContext()
    let file = try insertFile(title: "Growth 定例", into: context)
    let project = Project(title: "プロジェクト")
    file.projectID = project.id
    context.insert(project)
    try context.save()
    let core = makeCore(context: context)

    let projectPack = core.buildContext(
      for: .project(projectId: project.id),
      query: "進捗は？",
      userMemo: "機密メモ: この内容は file スコープ専用。"
    )
    let globalPack = core.buildContext(
      for: .global,
      query: "最近の動きは？",
      userMemo: "機密メモ: この内容は file スコープ専用。"
    )

    #expect(!projectPack.promptContext.contains("機密メモ"))
    #expect(!globalPack.promptContext.contains("機密メモ"))
  }
}
