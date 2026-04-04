import Testing
import Foundation
@testable import Memora

@MainActor
struct DataModelV2Tests {

    @Test("MeetingMemo は Markdown とプレーンテキストを保持できる")
    func meetingMemoStoresContent() {
        let audioFileID = UUID()
        let memo = MeetingMemo(
            audioFileID: audioFileID,
            markdown: "# 議題",
            plainTextCache: "議題"
        )

        #expect(memo.audioFileID == audioFileID)
        #expect(memo.markdown == "# 議題")
        #expect(memo.plainTextCache == "議題")

        memo.update(markdown: "## 決定事項", plainTextCache: "決定事項")

        #expect(memo.markdown == "## 決定事項")
        #expect(memo.plainTextCache == "決定事項")
        #expect(memo.updatedAt >= memo.createdAt)
    }

    @Test("PhotoAttachment は ownerType を enum で扱える")
    func photoAttachmentOwnerType() {
        let ownerID = UUID()
        let attachment = PhotoAttachment(
            ownerType: .memo,
            ownerID: ownerID,
            localPath: "/tmp/memo-photo.jpg"
        )

        #expect(attachment.ownerID == ownerID)
        #expect(attachment.ownerType == .memo)
        #expect(attachment.ownerTypeRaw == "memo")

        attachment.ownerType = .project
        attachment.updateCaption("会議ホワイトボード")
        attachment.updateOCRText("次回までにレビュー")

        #expect(attachment.ownerTypeRaw == "project")
        #expect(attachment.caption == "会議ホワイトボード")
        #expect(attachment.ocrText == "次回までにレビュー")
    }

    @Test("KnowledgeChunk は scope/source と検索補助情報を保持できる")
    func knowledgeChunkMetadata() {
        let scopeID = UUID()
        let sourceID = UUID()
        let chunk = KnowledgeChunk(
            scopeType: .project,
            scopeID: scopeID,
            sourceType: .memo,
            sourceID: sourceID,
            text: "API 移行は来週開始",
            keywords: ["API", "移行"],
            rankHint: 0.6
        )

        #expect(chunk.scopeType == .project)
        #expect(chunk.scopeID == scopeID)
        #expect(chunk.sourceType == .memo)
        #expect(chunk.sourceID == sourceID)
        #expect(chunk.keywords == ["API", "移行"])
        #expect(chunk.rankHint == 0.6)

        chunk.updateText("API 移行は再来週開始", keywords: ["API", "移行", "延期"], rankHint: 0.8)

        #expect(chunk.text == "API 移行は再来週開始")
        #expect(chunk.keywords == ["API", "移行", "延期"])
        #expect(chunk.rankHint == 0.8)
    }

    @Test("Ask AI セッションとメッセージは scope と role を保持できる")
    func askAIModelsStoreConversation() {
        let scopeID = UUID()
        let session = AskAISession(scopeType: .file, scopeID: scopeID, title: "要点確認")
        let message = AskAIMessage(
            sessionID: session.id,
            role: .assistant,
            content: "次のアクションは2件です。",
            citationsJSON: "[{\"source\":\"summary\"}]"
        )

        #expect(session.scopeType == .file)
        #expect(session.scopeID == scopeID)
        #expect(session.title == "要点確認")

        session.rename("決定事項確認")

        #expect(session.title == "決定事項確認")
        #expect(message.sessionID == session.id)
        #expect(message.role == .assistant)
        #expect(message.roleRaw == "assistant")
        #expect(message.citationsJSON == "[{\"source\":\"summary\"}]")
    }

    @Test("MemoryProfile と MemoryFact は個人化設定を保持できる")
    func memoryModelsStorePreferences() {
        let profile = MemoryProfile(
            summaryStyle: "箇条書き",
            preferredLanguage: "ja",
            roleLabel: "PM",
            glossaryJSON: "{\"LLM\":\"大規模言語モデル\"}"
        )
        let fact = MemoryFact(
            profileID: profile.id,
            key: "product_name",
            value: "Memora",
            source: "user-approved",
            confidence: 0.7
        )

        #expect(profile.summaryStyle == "箇条書き")
        #expect(profile.preferredLanguage == "ja")
        #expect(profile.roleLabel == "PM")
        #expect(profile.glossaryJSON == "{\"LLM\":\"大規模言語モデル\"}")

        profile.update(
            summaryStyle: "結論先出し",
            preferredLanguage: "en",
            roleLabel: "Founder",
            glossaryJSON: "{\"RAG\":\"retrieval augmented generation\"}"
        )
        fact.confirm(confidence: 0.95)

        #expect(profile.summaryStyle == "結論先出し")
        #expect(profile.preferredLanguage == "en")
        #expect(profile.roleLabel == "Founder")
        #expect(profile.glossaryJSON == "{\"RAG\":\"retrieval augmented generation\"}")
        #expect(fact.lastConfirmedAt != nil)
        #expect(fact.confidence == 0.95)
    }
}
