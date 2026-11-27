import Foundation
import Testing
@testable import LiveTranslatorCore

@MainActor
struct PrototypeTests {
    @Test func incompleteSpeechNeverTranslatesOnTimeout() {
        let model = CaptionViewModel()
        let start = Date()
        model.setEnglish(Array(repeating: "word", count: 100).joined(separator: " "), at: start)
        #expect(!model.shouldTranslate(at: start.addingTimeInterval(3600)))
        #expect(model.translationStatus.contains("等待完整句子"))
    }

    @Test func completedSentenceTranslatesImmediatelyAndOnlyOnce() throws {
        let model = CaptionViewModel()
        model.setEnglish("The cat sleeps. The next sentence is growing")
        let unit = try #require(model.nextTranslationUnit)
        #expect(unit.text == "The cat sleeps.")
        #expect(model.shouldTranslate(at: Date()))
        #expect(model.acceptTranslation("貓在睡覺。", for: unit))
        #expect(!model.shouldTranslate(at: Date()))
        model.setEnglish("The cat sleeps. The next sentence is growing longer")
        #expect(!model.shouldTranslate(at: Date()))
        #expect(model.chinese == "貓在睡覺。")
    }

    @Test func correctionRejectsOldResultAndSchedulesReplacement() throws {
        let model = CaptionViewModel()
        model.setEnglish("The cat sleeps.")
        let old = try #require(model.nextTranslationUnit)
        model.setEnglish("The dog sleeps.")
        #expect(!model.acceptTranslation("貓在睡覺。", for: old))
        let corrected = try #require(model.nextTranslationUnit)
        #expect(corrected.id == old.id)
        #expect(model.acceptTranslation("狗在睡覺。", for: corrected))
        #expect(model.chinese == "狗在睡覺。")
        model.setEnglish("The dog sleeps peacefully.")
        #expect(model.chinese.isEmpty)
        #expect(model.nextTranslationUnit?.text == "The dog sleeps peacefully.")
    }

    @Test func editingFirstSentenceDoesNotRetranslateUnchangedSecond() throws {
        let model = CaptionViewModel()
        model.setEnglish("The cat sleeps. Another sentence.")
        let first = try #require(model.nextTranslationUnit)
        #expect(model.acceptTranslation("貓在睡覺。", for: first))
        let second = try #require(model.nextTranslationUnit)
        #expect(model.acceptTranslation("另一句。", for: second))
        model.setEnglish("The little cat sleeps. Another sentence.")
        let correction = try #require(model.nextTranslationUnit)
        #expect(model.acceptTranslation("小貓在睡覺。", for: correction))
        #expect(model.nextTranslationUnit == nil)
        #expect(model.chinese == "小貓在睡覺。\n另一句。")
    }

    @Test func removedPunctuationRejectsInFlightResult() throws {
        let model = CaptionViewModel()
        model.setEnglish("The cat sleeps.")
        let old = try #require(model.nextTranslationUnit)
        model.setEnglish("The cat sleeps on the")
        #expect(!model.acceptTranslation("貓在睡覺。", for: old))
        #expect(model.nextTranslationUnit == nil)
    }

    @Test func clearingRejectsOldResultsAndDoesNotRestoreOldSnapshot() throws {
        let model = CaptionViewModel()
        model.setEnglish("The cat sleeps.")
        let old = try #require(model.nextTranslationUnit)
        model.clearCaptions()
        #expect(model.captionRows.isEmpty)
        #expect(!model.acceptTranslation("舊翻譯", for: old))
        model.setEnglish("The cat sleeps.")
        #expect(model.captionRows.isEmpty)
        model.setEnglish("The cat sleeps. Another sentence.")
        #expect(model.captionRows.map(\.english) == ["Another sentence."])
    }

    @Test func liveTranslationPrioritizesNewestWithoutDiscardingHistory() throws {
        let model = CaptionViewModel()
        model.setEnglish("The first sentence. The second sentence. The newest sentence.")
        #expect(model.pendingTranslationCount == 3)
        let newest = try #require(model.translationCandidate(prioritizeLatest: true))
        #expect(newest.text == "The newest sentence.")
        #expect(model.acceptTranslation("最新一句。", for: newest))
        #expect(model.pendingTranslationCount == 2)
        #expect(model.translationCandidate(prioritizeLatest: true)?.text == "The second sentence.")
        #expect(model.translationCandidate(prioritizeLatest: false)?.text == "The first sentence.")
        #expect(model.captionRows.count == 3)
        model.setEnglish("The first sentence. The second sentence. The newest sentence. A more recent sentence. An incomplete tail")
        #expect(model.translationCandidate(prioritizeLatest: true)?.text == "A more recent sentence.")
        #expect(model.captionRows.count == 5)
    }

    @Test func captureUpdateTimeTracksEnglishChangesOnly() {
        let model = CaptionViewModel()
        let time = Date(timeIntervalSince1970: 1000)
        model.setEnglish("A sentence.", at: time)
        model.setEnglish("A sentence.", at: time.addingTimeInterval(5))
        #expect(model.lastCaptionChangeAt == time)
        model.setEnglish("A new sentence.", at: time.addingTimeInterval(10))
        #expect(model.lastCaptionChangeAt == time.addingTimeInterval(10))
    }

    @Test func preparingOnStartCreatesConfigurationWithoutResettingReadySession() {
        let model = CaptionViewModel()
        #expect(model.configuration == nil)
        model.prepareTranslationIfNeeded()
        let version = model.configuration?.version
        #expect(version != nil)
        model.prepareTranslationIfNeeded()
        #expect(model.configuration?.version == version)
    }

    @Test func latestCaptionBlockIsSelectedInsteadOfOldHistory() {
        #expect(CaptionTextSelector.latest(from: ["Old sentence.", "The newest sentence."]) == "The newest sentence.")
        #expect(CaptionTextSelector.latest(from: ["The newest sentence.", "已暫停", " "]) == "The newest sentence.")
        #expect(CaptionTextSelector.latest(from: ["A single rolling caption."]) == "A single rolling caption.")
        #expect(CaptionTextSelector.latest(from: ["Paused"]) == nil)
    }

    @Test func stopInvalidatesInFlightRevision() {
        let model = CaptionViewModel()
        let revision = model.revision
        model.stop()
        #expect(!model.running)
        #expect(model.revision > revision)
    }

    @Test func translationRetryInvalidatesConfiguration() {
        let model = CaptionViewModel()
        model.prepareTranslation()
        let previous = model.configuration?.version
        model.prepareTranslation()
        #expect(model.configuration?.version != previous)
    }
}
