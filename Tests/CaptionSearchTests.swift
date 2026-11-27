import Foundation
import Testing
@testable import LiveTranslatorCore

struct CaptionSearchTests {
    private func row(_ id: Int, _ english: String, _ chinese: String?) -> CaptionDisplayRow {
        CaptionDisplayRow(id: id, english: english, chinese: chinese, complete: chinese != nil, timestamp: Date(), elapsed: 0)
    }

    @Test func searchesBothLanguagesAndPendingEnglishLiterally() {
        let rows = [row(1, "Coffee at the café.", "在咖啡廳喝咖啡。"), row(2, "Pending sentence [draft]", nil)]
        #expect(CaptionSearch.matches(rows, query: "CAFE").map(\.id) == [1])
        #expect(CaptionSearch.matches(rows, query: "咖啡").map(\.id) == [1])
        #expect(CaptionSearch.matches(rows, query: "[draft]").map(\.id) == [2])
        #expect(CaptionSearch.matches(rows, query: "ＡＴ").map(\.id) == [1])
        #expect(CaptionSearch.matches(rows, query: "  ").isEmpty)
        #expect(CaptionSearch.matches(rows, query: "missing").isEmpty)
    }

    @Test func navigationWrapsAndMatchesArePerSentence() {
        let rows = [row(1, "word word", "word"), row(2, "Another word", nil)]
        let matches = CaptionSearch.matches(rows, query: "word")
        #expect(matches.count == 2)
        #expect(CaptionSearch.movedID(in: matches, currentID: 1, step: 1) == 2)
        #expect(CaptionSearch.movedID(in: matches, currentID: 2, step: 1) == 1)
        #expect(CaptionSearch.movedID(in: matches, currentID: 1, step: -1) == 2)
        #expect(CaptionSearch.movedID(in: [], currentID: nil, step: 1) == nil)
    }
}
