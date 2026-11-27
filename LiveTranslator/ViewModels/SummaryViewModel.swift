import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class SummaryViewModel {
    var result: SummaryResult?
    var status = "尚未開始整理"
    var errorMessage: String?
    private(set) var isRunning = false
    var isExporting = false
    private var task: Task<Void, Never>?
    private var operation = UUID()

    func start(rows: [CaptionDisplayRow], service: SummaryService = SummaryService(generator: AppleSummaryGenerator())) {
        guard !isRunning, !isExporting else { return }
        guard !SummaryService.sources(from: rows).isEmpty else {
            errorMessage = SummaryError.empty.localizedDescription
            return
        }
        let capturedAt = Date()
        let token = UUID()
        operation = token
        result = nil
        errorMessage = nil
        status = "檢查裝置端模型…"
        isRunning = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { if operation == token { isRunning = false; task = nil } }
            do {
                let generated = try await service.summarize(rows: rows, capturedAt: capturedAt) { [weak self] in self?.status = $0 }
                try Task.checkCancellation()
                guard operation == token else { return }
                result = generated
                status = "整理完成 · 僅包含按下按鈕時的字幕"
            } catch {
                guard operation == token else { return }
                if Task.isCancelled {
                    status = "已取消整理"
                } else {
                    status = "整理未完成"
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        if isRunning { status = "正在取消…" }
    }

    func copy() {
        guard let result else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.markdown, forType: .string)
        status = "已複製摘要及英文來源"
    }

    func export() {
        guard let result, !isExporting else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "LiveTranslator-summary-\(result.capturedAt.formatted(.iso8601.year().month().day().dateSeparator(.dash))).md"
        isExporting = true
        panel.begin { [weak self] response in
            guard let self else { return }
            isExporting = false
            guard response == .OK, let url = panel.url else { return }
            do {
                try result.markdown.write(to: url, atomically: true, encoding: .utf8)
                status = "已儲存：\(url.lastPathComponent)"
            } catch { errorMessage = "儲存失敗：\(error.localizedDescription)" }
        }
    }
}
