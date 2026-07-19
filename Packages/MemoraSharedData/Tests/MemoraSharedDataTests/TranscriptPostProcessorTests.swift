import Foundation
import Testing
@testable import MemoraSharedCore

@Suite("Transcript post processor")
struct TranscriptPostProcessorTests {
    @Test("行頭のフィラーを除去する")
    func removesLeadingFiller() {
        #expect(TranscriptPostProcessor().clean("えー、それでですね") == "それでですね")
    }

    @Test("文中で読点に挟まれたフィラーを除去する")
    func removesInlineFiller() {
        #expect(TranscriptPostProcessor().clean("会議は、えっと、明日の10時です") == "会議は、明日の10時です")
    }

    @Test("単独行のフィラーを除去する")
    func removesStandaloneFiller() {
        #expect(TranscriptPostProcessor().clean("うーん\n確認します") == "確認します")
    }

    @Test("フィラーを含まない文を変更しない")
    func preservesTextWithoutFillers() {
        let text = "来週の会議では売上計画を確認します。"
        #expect(TranscriptPostProcessor().clean(text) == text)
    }

    @Test("あの人を連体詞として保持する")
    func preservesAnoHito() {
        #expect(TranscriptPostProcessor().clean("あの人に確認してください") == "あの人に確認してください")
    }

    @Test("その件を連体詞として保持する")
    func preservesSonoKen() {
        #expect(TranscriptPostProcessor().clean("その件は明日対応します") == "その件は明日対応します")
    }

    @Test("語の一部に含まれるフィラーを保持する")
    func preservesFillerInsideWord() {
        #expect(TranscriptPostProcessor().clean("そのそのものを確認します") == "そのそのものを確認します")
    }

    @Test("接頭辞・数値を保持しつつ読点で区切られた言い直しを正規化する", arguments: [
        ("5、50個です。", "5、50個です。"),
        ("1、10日に決済します。", "1、10日に決済します。"),
        ("母、母親が来た。", "母、母親が来た。"),
        ("赤、赤色を選ぶ。", "赤、赤色を選ぶ。"),
        ("あ、ありがとうございます。", "あ、ありがとうございます。"),
        ("これは、これは重要です。", "これは重要です。"),
        ("私は、私は行きます。", "私は行きます。"),
        ("はい、はい。", "はい。")
    ])
    func normalizesOnlyImmediateRepetition(text: String, expected: String) {
        #expect(TranscriptPostProcessor().clean(text) == expected)
    }

    @Test("複合語・固有名詞・数値の接頭辞を言い直しとして削除しない", arguments: [
        ("会議、会議室を予約します。", "会議、会議室を予約します。"),
        ("決済、決済サイクルの話です。", "決済、決済サイクルの話です。"),
        ("解約、解約率が上がる。", "解約、解約率が上がる。"),
        ("代理、代理店の話。", "代理、代理店の話。"),
        ("山田、山田さんが来ました。", "山田、山田さんが来ました。"),
        ("第1、第10期の数字です。", "第1、第10期の数字です。"),
        ("15、15日に決済。", "15、15日に決済。"),
        ("これは、これは重要です。", "これは重要です。"),
        ("私は、私は行きます。", "私は行きます。"),
        ("はい、はい。", "はい。")
    ])
    func normalizesOnlyCompletePhrases(text: String, expected: String) {
        #expect(TranscriptPostProcessor().clean(text) == expected)
    }

    @Test("空白と句読点の既存正規化を維持する")
    func preservesWhitespaceAndPunctuationNormalization() {
        #expect(TranscriptPostProcessor().clean("今日は  テスト です。。") == "今日はテストです。")
    }

    @Test("改行の既存正規化を維持する")
    func preservesLineBreakNormalization() {
        #expect(TranscriptPostProcessor().clean("一行目\n\n\n二行目") == "一行目\n\n二行目")
    }

    @Test("空文字と記号のみの入力を安全に処理する", arguments: [
        ("", ""),
        ("、、、", "、"),
        ("！？！？", "！？！？")
    ])
    func handlesEmptyAndPunctuationOnly(text: String, expected: String) {
        #expect(TranscriptPostProcessor().clean(text) == expected)
    }

    @Test("長文の各行にあるフィラーを処理する")
    func handlesLongInput() {
        let text = Array(repeating: "えー、それでですね", count: 2_000).joined(separator: "\n")
        let cleaned = TranscriptPostProcessor().clean(text)
        #expect(cleaned.contains("えー") == false)
        #expect(cleaned.split(separator: "\n").count == 2_000)
    }

    @Test("フィラー辞書を呼び出し側で差し替えられる")
    func supportsCustomFillerDictionary() {
        let processor = TranscriptPostProcessor(fillers: ["えーと"])
        #expect(processor.clean("えーと、それで進めます") == "それで進めます")
        #expect(processor.clean("えー、それで進めます") == "えー、それで進めます")
    }
}
