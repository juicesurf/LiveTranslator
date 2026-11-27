import Foundation
import Testing
@testable import LiveTranslatorCore

@MainActor
private final class RecordingSummaryGenerator: SummaryGenerating {
    var inputs: [SummaryInput] = []
    var slow = false
    var invalid = false
    var verbose = false
    var compactionFails = false
    func generate(_ input: SummaryInput) async throws -> SummaryDraft {
        inputs.append(input)
        if input.concise && compactionFails { throw SummaryError.contextTooLarge }
        if slow { try await Task.sleep(for: .seconds(10)) }
        return SummaryDraft(overview: verbose && !input.concise ? String(repeating: "摘要", count: 100) : "測試摘要", keyPoints: [SummaryPoint(text: "測試重點", sourceIDs: invalid ? [-1] : Array(input.sourceIDs.sorted().prefix(2)), evidence: "")], actionItems: [])
    }
}

@MainActor
@Suite(.serialized)
struct SummaryTests {
    private func row(_ id: Int, _ text: String, complete: Bool = true) -> CaptionDisplayRow {
        CaptionDisplayRow(id: id, english: text, chinese: "這個譯文不應傳入摘要", complete: complete, timestamp: Date(), elapsed: Double(id * 10))
    }

    @Test func onlyCompletedEnglishAndOriginalTimesBecomeSources() {
        let rows = [row(0, "Original English."), row(1, "unfinished", complete: false), row(2, "   ")]
        let sources = SummaryService.sources(from: rows)
        #expect(sources.count == 1)
        #expect(sources[0].text == "Original English.")
        #expect(sources[0].elapsed == 0)
        let input = SummaryService.inputs(from: sources)[0]
        #expect(!input.text.contains("譯文"))
        #expect(input.text.contains("00:00:00"))
    }

    @Test func oversizedSentenceIsBoundedWithoutDroppingText() {
        let text = String(repeating: "A long sentence 中文 ", count: 600)
        let inputs = SummaryService.inputs(from: [SummarySource(id: 1, text: text, elapsed: 5)])
        #expect(inputs.count > 1)
        #expect(inputs.allSatisfy { $0.text.utf8.count <= 2300 })
        let restored = inputs.map { input in String(input.text.dropFirst(input.text.firstIndex(of: "]").map { input.text.distance(from: input.text.startIndex, to: $0) + 2 } ?? 0)) }.joined()
        #expect(restored == text)
        #expect(inputs.allSatisfy { $0.sourceIDs == [1] })
    }

    @Test func longTranscriptIsMergedAndEmptyActionsRemainEmpty() async throws {
        let generator = RecordingSummaryGenerator()
        let rows = (0..<9).map { row($0, String(repeating: "Evidence ", count: 100) + ".") }
        let inputs = SummaryService.inputs(from: SummaryService.sources(from: rows))
        let result = try await SummaryService(generator: generator).summarize(rows: rows, capturedAt: .distantPast, progress: { _ in })
        #expect(generator.inputs.count == inputs.count * 2 - 1)
        #expect(result.sources.count == 9)
        #expect(result.draft.actionItems.isEmpty)
        #expect(result.capturedAt == .distantPast)
        #expect(result.markdown.contains("## 英文來源"))
        #expect(result.references(result.draft.keyPoints[0]).contains("00:00:00"))
    }

    @Test func unsupportedReferencesAreRejected() async {
        let generator = RecordingSummaryGenerator()
        generator.invalid = true
        await #expect(throws: SummaryError.self) {
            _ = try await SummaryService(generator: generator).summarize(rows: [row(0, "Evidence.")], capturedAt: Date(), progress: { _ in })
        }
    }

    @Test func actionRequiresVerbatimExplicitCommitment() {
        let sources = [1: "Maya will test the login page before launch.", 2: "The budget has not been decided."]
        let valid = SummaryPoint(text: "Maya 測試登入頁面", sourceIDs: [1], evidence: sources[1]!)
        let invented = SummaryPoint(text: "確定預算", sourceIDs: [2], evidence: sources[2]!)
        let fakeQuote = SummaryPoint(text: "確定預算", sourceIDs: [2], evidence: "The team will decide the budget.")
        #expect(SummaryService.hasExplicitActionEvidence(valid, sources: sources))
        #expect(!SummaryService.hasExplicitActionEvidence(invented, sources: sources))
        #expect(!SummaryService.hasExplicitActionEvidence(fakeQuote, sources: sources))
    }

    @Test func verboseSummaryAutomaticallyRetriesWithSameSources() async throws {
        let generator = RecordingSummaryGenerator()
        generator.verbose = true
        let result = try await SummaryService(generator: generator).summarize(rows: [row(0, "Evidence.")], capturedAt: Date(), progress: { _ in })
        #expect(generator.inputs.count == 2)
        #expect(generator.inputs[1].concise)
        #expect(generator.inputs[0].text == generator.inputs[1].text)
        #expect(result.draft.overview == "測試摘要")
        #expect(result.warnings.isEmpty)
    }

    @Test func failedCompactionPreservesFullValidDraftWithWarning() async throws {
        let generator = RecordingSummaryGenerator()
        generator.verbose = true
        generator.compactionFails = true
        let result = try await SummaryService(generator: generator).summarize(rows: [row(0, "Evidence.")], capturedAt: Date(), progress: { _ in })
        #expect(result.draft.overview == String(repeating: "摘要", count: 100))
        #expect(!result.warnings.isEmpty)
        #expect(result.markdown.contains("摘要較長"))
        #expect(result.sources.count == 1)
    }

    @Test func emptyTranscriptDoesNotCallModel() async {
        let generator = RecordingSummaryGenerator()
        await #expect(throws: SummaryError.self) {
            _ = try await SummaryService(generator: generator).summarize(rows: [row(0, "pending", complete: false)], capturedAt: Date(), progress: { _ in })
        }
        #expect(generator.inputs.isEmpty)
    }

    @Test func cancellationNeverPublishesLateResult() async throws {
        let generator = RecordingSummaryGenerator()
        generator.slow = true
        let model = SummaryViewModel()
        model.start(rows: [row(0, "Evidence.")], service: SummaryService(generator: generator))
        try await Task.sleep(for: .milliseconds(30))
        model.cancel()
        try await Task.sleep(for: .milliseconds(30))
        #expect(!model.isRunning)
        #expect(model.result == nil)
        #expect(model.status == "已取消整理")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_TRANSLATOR_MODEL_SMOKE"] == "1"))
    func actualAppleModelMergesMultipleEnglishChunks() async throws {
        let sentence = "The lecture explains how shared experiences can help people begin conversations without preparing elaborate opening lines. "
        let rows = [row(0, String(repeating: sentence, count: 11)), row(1, String(repeating: sentence, count: 11))]
        #expect(SummaryService.inputs(from: SummaryService.sources(from: rows)).count > 1)
        let result = try await SummaryService(generator: AppleSummaryGenerator()).summarize(rows: rows, capturedAt: Date(), progress: { print($0) })
        #expect(!result.draft.overview.isEmpty)
        #expect(result.draft.actionItems.isEmpty)
        #expect(result.sources.count == 2)
        print("Merged fixed sample: \(result.draft.overview)")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_TRANSLATOR_MODEL_SMOKE"] == "1"))
    func actualAppleModelProducesTraditionalChineseSummary() async throws {
        let rows = [row(0, "The team will launch the website on Friday."), row(1, "Maya will test the login page before launch."), row(2, "The budget has not been decided.")]
        let result = try await SummaryService(generator: AppleSummaryGenerator(inspectDraft: { draft in
            for item in draft.actionItems { print("Raw action: \(item.text); evidence: \(item.evidence)") }
        })).summarize(rows: rows, capturedAt: Date(), progress: { _ in })
        #expect(!result.draft.keyPoints.isEmpty)
        #expect(!result.draft.overview.isEmpty)
        #expect(!result.draft.actionItems.isEmpty)
        #expect(!result.draft.actionItems.contains { $0.sourceIDs == [3] })
        #expect(result.draft.actionItems.contains { $0.text.contains("Maya") && $0.sourceIDs.contains(2) })
        print("Fixed sample summary: \(result.draft.overview)")
        for point in result.draft.keyPoints { print("Point: \(point.text) [\(point.sourceIDs)]") }
        for point in result.draft.actionItems { print("Action: \(point.text) [\(point.sourceIDs)]") }
    }
}
