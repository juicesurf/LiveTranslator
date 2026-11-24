import Testing
@testable import LiveTranslatorCore

struct CaptionProcessorTests {
    @Test func incrementalAndDuplicateSnapshotsKeepIdentity() {
        var processor = CaptionProcessor()
        let first = processor.consume("It's low stakes enough")
        let next = processor.consume("It's low stakes enough that even if your grammar isn't perfect.")
        #expect(first[0].id == next[0].id)
        #expect(next[0].complete)
        #expect(processor.consume(next[0].text) == next)
    }
    @Test func correctionReplacesSameOccurrence() {
        var processor = CaptionProcessor()
        let first = processor.consume("The cat is here.")
        let corrected = processor.consume("The cap is here.")
        #expect(first[0].id == corrected[0].id)
        #expect(corrected.count == 1)
        #expect(corrected[0].text == "The cap is here.")
    }
    @Test func scrollingPreservesCompletedSentences() {
        var processor = CaptionProcessor()
        let first = processor.consume("First sentence. Another sentence is growing")
        let next = processor.consume("Another sentence is growing longer. New sentence.")
        #expect(next[0] == first[0])
        #expect(next.count == 3)
        #expect(next[1].id == first[1].id)
    }
    @Test func actualRepetitionHasSeparateIdentity() {
        var processor = CaptionProcessor()
        let result = processor.consume("Thank you. Thank you.")
        #expect(result.count == 2)
        #expect(result[0].text == result[1].text)
        #expect(result[0].id != result[1].id)
    }
    @Test func longUnpunctuatedSpeechStaysPending() {
        var processor = CaptionProcessor()
        let result = processor.consume(Array(repeating: "word", count: 55).joined(separator: " "))
        #expect(result.count == 1)
        #expect(!result[0].complete)
        #expect(result[0].text.split(separator: " ").count == 55)
    }
    @Test func abbreviationsDecimalsAndQuotedEndings() {
        var processor = CaptionProcessor()
        let result = processor.consume("Dr. Smith said e.g. the value is 3.14 and J. Doe agrees. He asked, “Really?” Yes!")
        #expect(result.map(\.text) == ["Dr. Smith said e.g. the value is 3.14 and J. Doe agrees.", "He asked, “Really?”", "Yes!"])
        #expect(result.allSatisfy { $0.complete })
    }
    @Test func acronymAndEllipsisDoNotPrematurelyFinish() {
        var processor = CaptionProcessor()
        let result = processor.consume("The U.S. team is thinking...")
        #expect(result.count == 1)
        #expect(!result[0].complete)
    }
    @Test func punctuationAddedAndRemovedUpdatesCompletion() {
        var processor = CaptionProcessor()
        let pending = processor.consume("This is a sentence")
        let complete = processor.consume("This is a sentence.")
        let revised = processor.consume("This is a sentence with more")
        #expect(pending[0].id == complete[0].id)
        #expect(complete[0].complete)
        #expect(revised.count == 1)
        #expect(!revised[0].complete)
    }
    @Test func correctionWithInsertedWordsKeepsFollowingSentence() {
        var processor = CaptionProcessor()
        let original = processor.consume("The cat sleeps. Another sentence.")
        let revised = processor.consume("The little cat sleeps. Another sentence.")
        #expect(revised.map(\.text) == ["The little cat sleeps.", "Another sentence."])
        #expect(revised[1].id == original[1].id)
    }
    @Test func rollingWindowWithCorrectedWordDoesNotAppendDuplicateBlock() {
        var processor = CaptionProcessor()
        _ = processor.consume("First sentence. The cat is sleeping on the mat.")
        let result = processor.consume("The dog is sleeping on the mat. Another sentence.")
        #expect(result.map(\.text) == ["First sentence.", "The dog is sleeping on the mat.", "Another sentence."])
    }
    @Test func rollingWindowWithInsertedWordDoesNotDuplicateOverlap() {
        var processor = CaptionProcessor()
        _ = processor.consume("First sentence. The cat is sleeping")
        let result = processor.consume("The little cat is sleeping peacefully.")
        #expect(result.map(\.text) == ["First sentence.", "The little cat is sleeping peacefully."])
    }
    @Test func rollingWindowIgnoresPunctuationAndCapitalizationForMatching() {
        var processor = CaptionProcessor()
        _ = processor.consume("First sentence. Commenting on something creates a connection")
        let result = processor.consume("commenting on something creates a connection. New sentence.")
        #expect(result.map(\.text) == ["First sentence.", "commenting on something creates a connection.", "New sentence."])
    }
    @Test func lectureWindowCorrectionDoesNotRepeatUnchangedSentences() {
        var processor = CaptionProcessor()
        _ = processor.consume("Commenting on something creates a connection. I think that shared situation approach genuinely works so well because it requires absolutely zero preparation. You're simply responding naturally to whatever is happening around you.")
        let result = processor.consume("I think that shared situation approach genuinely works so well, because it requires absolutely zero preparation. You're simply responding naturally to whatever is happening around you. I've used this strategy while travelling.")
        #expect(result.count == 4)
        #expect(result.filter { $0.text.hasPrefix("I think that shared") }.count == 1)
        #expect(result.filter { $0.text.hasPrefix("You're simply") }.count == 1)
    }
    @Test func repeatedSpokenSentenceStillGetsNewOccurrenceAfterWindowRolls() {
        var processor = CaptionProcessor()
        _ = processor.consume("Thank you. We are all here.")
        let result = processor.consume("We are all here. Thank you.")
        #expect(result.map(\.text) == ["Thank you.", "We are all here.", "Thank you."])
        #expect(Set(result.map(\.id)).count == 3)
    }
    @Test func unrelatedSnapshotAppendsNewOccurrence() {
        var processor = CaptionProcessor()
        _ = processor.consume("Old sentence.")
        let result = processor.consume("Completely new topic.")
        #expect(result.count == 2)
    }
}
