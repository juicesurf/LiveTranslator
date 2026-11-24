import Foundation
import Testing
@testable import LiveTranslatorCore

@MainActor
struct TranscriptTests {
    @Test func sentenceKeepsFirstTimestampThroughCorrectionsAndTranslation() throws {
        let model = CaptionViewModel()
        let start = Date(timeIntervalSince1970: 1000)
        model.setEnglish("The cat", at: start)
        model.setEnglish("The cat sleeps.", at: start.addingTimeInterval(12))
        #expect(model.captionRows[0].timestamp == start)
        #expect(model.captionRows[0].elapsed == 0)
        let unit = try #require(model.nextTranslationUnit)
        #expect(model.acceptTranslation("貓在睡覺。", for: unit))
        model.setEnglish("The dog sleeps. Another sentence.", at: start.addingTimeInterval(65))
        #expect(model.captionRows[0].timestamp == start)
        #expect(model.captionRows[1].elapsed == 65)
    }

    @Test func exportedSnapshotDoesNotMarkLaterChangesSaved() throws {
        let model = CaptionViewModel()
        model.setEnglish("The cat sleeps.")
        #expect(model.hasUnsavedChanges)
        let snapshot = model.captionRows
        model.markExported(snapshot)
        #expect(!model.hasUnsavedChanges)
        let unit = try #require(model.nextTranslationUnit)
        _ = model.acceptTranslation("貓在睡覺。", for: unit)
        #expect(model.hasUnsavedChanges)
        model.markExported(snapshot)
        #expect(model.hasUnsavedChanges)
        model.markExported(model.captionRows)
        model.setEnglish("The dog sleeps.")
        #expect(model.hasUnsavedChanges)
        model.clearCaptions()
        #expect(!model.hasUnsavedChanges)
    }

    @Test func decisionFlowFreezesUpdatesAndResumesAfterCancellation() throws {
        let model = CaptionViewModel()
        model.setEnglish("The cat sleeps.")
        let unit = try #require(model.nextTranslationUnit)
        let snapshot = model.captionRows
        model.protectTranscript(true)
        model.setEnglish("The cat sleeps. Another sentence.")
        #expect(model.captionRows == snapshot)
        #expect(!model.acceptTranslation("貓在睡覺。", for: unit))
        #expect(!model.shouldTranslate(at: Date()))
        model.protectTranscript(false)
        model.setEnglish("The cat sleeps. Another sentence.")
        #expect(model.captionRows.count == 2)
        #expect(model.shouldTranslate(at: Date()))
    }

    @Test func exportIncludesElapsedTimePairedLanguagesAndPendingStatus() throws {
        let model = CaptionViewModel()
        let start = Date(timeIntervalSince1970: 1000)
        model.setEnglish("The cat sleeps.", at: start)
        let unit = try #require(model.nextTranslationUnit)
        _ = model.acceptTranslation("貓在睡覺。", for: unit)
        model.setEnglish("The cat sleeps. Next thought", at: start.addingTimeInterval(65))
        let text = TranscriptService.plainText(rows: model.captionRows, exportedAt: start)
        #expect(text.contains("[00:00:00] [已翻譯]\nThe cat sleeps.\n貓在睡覺。"))
        #expect(text.contains("[00:01:05] [英文未完成]\nNext thought\n[英文未完成]"))
        #expect(TranscriptService.elapsedLabel(3661) == "01:01:01")
        #expect(TranscriptService.elapsedLabel(-3) == "00:00:00")
    }

    @Test func markdownEscapesCaptionMarkupAndPreservesChinese() {
        let row = CaptionDisplayRow(id: 0, english: "Use *bold* and <tag>.", chinese: "保留中文與 [括號]。", complete: true,
                                    timestamp: Date(), elapsed: 5)
        let text = TranscriptService.document(rows: [row], exportedAt: Date(), format: .markdown)
        #expect(text.contains("### 00:00:05 · 已翻譯"))
        #expect(text.contains("Use \\*bold\\* and \\<tag\\>\\."))
        #expect(text.contains("保留中文與 \\[括號\\]。"))
    }
}
