import Foundation
import Testing
@testable import LiveTranslatorCore

@MainActor
struct CaptionSourceTests {
    @Test func latePeriodOnPreviousNodeSplitsSentencesWithoutDuplication() throws {
        var processor = CaptionProcessor()
        let first = "Winter mornings feel almost impossible compared to summer ones"
        let second = "I think a lot of people don't realise how much artificial light at night can mess with this rhythm too."
        let pending = try #require(CaptionTextSelector.snapshot(from: [first]))
        #expect(!processor.consume(pending)[0].complete)
        let corrected = try #require(CaptionTextSelector.snapshot(from: [first + ".", second]))
        let rows = processor.consume(corrected)
        #expect(rows.count == 2)
        #expect(rows[0].text == first + ".")
        #expect(rows[1].text == second)
        #expect(rows.allSatisfy { $0.complete })
        let next = try #require(CaptionTextSelector.snapshot(from: [second, "Another sentence."]))
        #expect(processor.consume(next).map(\.text) == [first + ".", second, "Another sentence."])
    }

    @Test func emptyAreaDoesNotHideValidCaptionArea() {
        #expect(CaptionTextSelector.snapshot(fromAreas: [[], ["Paused"], ["Current caption."]]) == "Current caption.")
        #expect(CaptionTextSelector.snapshot(fromAreas: [[], ["Paused"]]) == nil)
    }

    @Test func overlappingNodesDoNotDuplicateSharedWordsOrLosePunctuation() {
        let text = CaptionTextSelector.snapshot(from: ["Earlier sentence. The latest sentence", "The latest sentence grows."])
        #expect(text == "Earlier sentence. The latest sentence grows.")
        #expect(CaptionTextSelector.snapshot(from: ["Thank you.", "Thank you."]) == "Thank you.\nThank you.")
        #expect(CaptionTextSelector.snapshot(from: ["Old history.", "Previous sentence.", "Current sentence.", "已暫停"]) == "Previous sentence.\nCurrent sentence.")
    }

    @Test func failedReadRetainsLastSuccessfulRawTextAndDoesNotReplayIt() {
        let model = CaptionViewModel()
        let time = Date(timeIntervalSince1970: 1000)
        model.applyCaptionRead(CaptionRead(text: "Summer ones. I think so.", status: "成功", diagnostics: "AXValue: Summer ones. I think so."), at: time)
        let rows = model.captionRows
        model.applyCaptionRead(CaptionRead(status: "未讀到字幕", diagnostics: "字幕文字節點數：0"), at: time.addingTimeInterval(10))
        #expect(model.captionRows == rows)
        #expect(model.lastCaptionChangeAt == time)
        #expect(model.diagnostics.contains("字幕文字節點數：0"))
        #expect(model.diagnostics.contains("最後成功"))
        #expect(model.diagnostics.contains("AXValue: Summer ones. I think so."))
        #expect(model.connectionStatus == "未讀到字幕")
        model.applyCaptionRead(CaptionRead(text: "I think so. A new sentence.", status: "已恢復"), at: time.addingTimeInterval(20))
        #expect(model.captionRows.last?.english == "A new sentence.")
        #expect(model.lastCaptionChangeAt == time.addingTimeInterval(20))
    }
}
