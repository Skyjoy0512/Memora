import Testing
import Foundation
import SwiftData
@testable import Memora

struct MemoryExtractionServiceTests {

    // MARK: - MemoryCandidateDraft

    @Test("MemoryCandidateDraft のプロパティが正しく設定される")
    func candidateDraftProperties() {
        let draft = MemoryCandidateDraft(
            key: "preferredLanguage",
            value: "日本語",
            confidence: 0.8,
            source: "auto:summary"
        )
        #expect(draft.key == "preferredLanguage")
        #expect(draft.value == "日本語")
        #expect(draft.confidence == 0.8)
        #expect(draft.source == "auto:summary")
    }

    @Test("MemoryCandidateDraft のデフォルト source タグが正しい")
    func candidateDraftSourceTags() {
        let fromSummary = MemoryCandidateDraft(
            key: "role",
            value: "PM",
            confidence: 0.6,
            source: "auto:summary"
        )
        let fromTranscription = MemoryCandidateDraft(
            key: "schedule",
            value: "毎週火曜ミーティング",
            confidence: 0.6,
            source: "auto:transcription"
        )
        #expect(fromSummary.source == "auto:summary")
        #expect(fromTranscription.source == "auto:transcription")
    }

    // MARK: - MemoryProfile

    @Test("MemoryProfile の初期値が正しい")
    func memoryProfileDefaults() {
        let profile = MemoryProfile()
        #expect(profile.summaryStyle == nil)
        #expect(profile.preferredLanguage == nil)
        #expect(profile.roleLabel == nil)
        #expect(profile.glossaryJSON == nil)
    }

    @Test("MemoryProfile の全パラメータ設定が正しい")
    func memoryProfileAllParams() {
        let profile = MemoryProfile(
            summaryStyle: "箇条書き",
            preferredLanguage: "日本語",
            roleLabel: "プロジェクトマネージャー",
            glossaryJSON: "{\"Sprint\":\"開発区間\"}"
        )
        #expect(profile.summaryStyle == "箇条書き")
        #expect(profile.preferredLanguage == "日本語")
        #expect(profile.roleLabel == "プロジェクトマネージャー")
        #expect(profile.glossaryJSON == "{\"Sprint\":\"開発区間\"}")
    }

    @Test("MemoryProfile.update() が値を更新する")
    func memoryProfileUpdate() {
        let profile = MemoryProfile(roleLabel: "エンジニア")
        let before = profile.updatedAt
        profile.update(roleLabel: "テックリード")

        #expect(profile.roleLabel == "テックリード")
        #expect(profile.updatedAt >= before)
    }

    @Test("MemoryProfile.update() で nil を渡すとクリアされる")
    func memoryProfileUpdateClears() {
        let profile = MemoryProfile(summaryStyle: "長文", preferredLanguage: "ja")
        profile.update(summaryStyle: nil, preferredLanguage: nil)

        #expect(profile.summaryStyle == nil)
        #expect(profile.preferredLanguage == nil)
    }

    // MARK: - MemoryFact

    @Test("MemoryFact の初期値が正しい")
    func memoryFactDefaults() {
        let profileID = UUID()
        let fact = MemoryFact(
            profileID: profileID,
            key: "preferredFormat",
            value: "Markdown",
            source: "auto:summary"
        )
        #expect(fact.profileID == profileID)
        #expect(fact.key == "preferredFormat")
        #expect(fact.value == "Markdown")
        #expect(fact.source == "auto:summary")
        #expect(fact.confidence == 0)
        #expect(fact.lastConfirmedAt == nil)
    }

    @Test("MemoryFact の confidence が設定される")
    func memoryFactConfidence() {
        let fact = MemoryFact(
            profileID: UUID(),
            key: "schedule",
            value: "毎週水曜定例",
            source: "auto:transcription",
            confidence: 0.85
        )
        #expect(fact.confidence == 0.85)
    }

    @Test("MemoryFact.confirm() が lastConfirmedAt を更新する")
    func memoryFactConfirm() {
        let fact = MemoryFact(
            profileID: UUID(),
            key: "role",
            value: "デザイナー",
            source: "auto:summary"
        )
        #expect(fact.lastConfirmedAt == nil)

        let confirmDate = Date()
        fact.confirm(at: confirmDate)
        #expect(fact.lastConfirmedAt == confirmDate)
    }

    @Test("MemoryFact.confirm() で confidence も更新できる")
    func memoryFactConfirmWithConfidence() {
        let fact = MemoryFact(
            profileID: UUID(),
            key: "project",
            value: "Memora",
            source: "auto:summary",
            confidence: 0.5
        )
        fact.confirm(confidence: 0.9)
        #expect(fact.confidence == 0.9)
        #expect(fact.lastConfirmedAt != nil)
    }

    // MARK: - MemoryFact ID uniqueness

    @Test("MemoryFact の ID が自動生成され一意")
    func memoryFactIDUniqueness() {
        let profileID = UUID()
        let fact1 = MemoryFact(profileID: profileID, key: "a", value: "1", source: "auto:summary")
        let fact2 = MemoryFact(profileID: profileID, key: "a", value: "1", source: "auto:summary")
        #expect(fact1.id != fact2.id)
    }
}
