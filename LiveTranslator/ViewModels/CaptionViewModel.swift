import AppKit
import UniformTypeIdentifiers
@preconcurrency import ApplicationServices
import Observation
@preconcurrency import Translation

struct CaptionDisplayRow: Identifiable, Equatable {
    let id: Int
    let english: String
    let chinese: String?
    let complete: Bool
    let timestamp: Date
    let elapsed: TimeInterval
    var translationFailed = false
    var status: CaptionStatus {
        if !complete { return .incomplete }
        if chinese != nil { return .translated }
        return translationFailed ? .failed : .pending
    }
}

@MainActor @Observable
final class CaptionViewModel {
    @ObservationIgnored weak var presentationWindow: NSWindow?
    var searchRequest = 0
    var english = ""
    var chinese = ""
    var connectionStatus = "尚未開始"
    var translationStatus = "尚未準備語言模型"
    var diagnostics = ""
    private(set) var lastCaptionChangeAt: Date?
    private var lastSuccessfulRead: (at: Date, text: String, details: String)?
    var running = false
    var configuration: TranslationSession.Configuration?
    private let reader = AccessibilityCaptionReader()
    private var polling: Task<Void, Never>?
    private(set) var revision = 0
    private var processor = CaptionProcessor()
    private var units: [CaptionUnit] = []
    private var clearedSources: [Int: String] = [:]
    private var translations: [Int: (source: String, result: String)] = [:]
    private var failed: [Int: String] = [:]
    var exportStatus = ""
    var isExporting = false
    var timingStatus = "尚無翻譯耗時"
    private var pendingSince: Date?
    private var generation = 0
    private var firstSeen: [Int: Date] = [:]
    private(set) var sessionStartedAt: Date?
    private var savedRows: [CaptionDisplayRow] = []
    private var preferredExportFormat = TranscriptFormat.txt
    private(set) var isProtectingTranscript = false

    var hasUnsavedChanges: Bool { !captionRows.isEmpty && captionRows != savedRows }

    func markExported(_ rows: [CaptionDisplayRow]) { savedRows = rows }

    func protectTranscript(_ protect: Bool) { isProtectingTranscript = protect }

    var captionRows: [CaptionDisplayRow] {
        units.map { unit in
            let translation = translations[unit.id]
            return CaptionDisplayRow(id: unit.id, english: unit.text,
                chinese: unit.complete && translation?.source == unit.text ? translation?.result : nil,
                complete: unit.complete,
                timestamp: firstSeen[unit.id] ?? sessionStartedAt ?? .distantPast,
                elapsed: max(0, (firstSeen[unit.id] ?? sessionStartedAt ?? .distantPast).timeIntervalSince(sessionStartedAt ?? .distantPast)),
                translationFailed: failed[unit.id] == unit.text)
        }
    }

    func saveTranscript(format: TranscriptFormat = .txt, completion: ((Bool) -> Void)? = nil) {
        guard !captionRows.isEmpty, !isExporting else { completion?(false); return }
        let rows = captionRows
        let now = Date()
        let text = TranscriptService.document(rows: rows, exportedAt: now, format: format)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .txt ? .plainText : (UTType(filenameExtension: "md") ?? .plainText)]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "LiveTranslator-\(now.formatted(.iso8601.year().month().day().dateSeparator(.dash))).\(format.fileExtension)"
        panel.title = "儲存中英逐字稿（\(format.title)）"
        panel.message = "儲存按下按鈕時的全部字幕，依時間、英文、中文逐句排列。"
        preferredExportFormat = format
        isExporting = true
        SavePanelPresenter.present(panel, from: presentationWindow) { [weak self] response in
            guard let self else { completion?(false); return }
            isExporting = false
            guard response == .OK, let url = panel.url else { completion?(false); return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                markExported(rows)
                exportStatus = "已儲存：\(url.lastPathComponent)"
                completion?(true)
            } catch {
                exportStatus = "儲存失敗：\(error.localizedDescription)"
                completion?(false)
            }
        }
    }

    /// Freeze mutations for the decision/save flow so a destructive action cannot lose
    /// subtitles that arrived after the exported snapshot. Cancellation resumes capture.
    func resolveUnsavedChanges(action: String, completion: @escaping (Bool) -> Void) {
        guard !isExporting, !isProtectingTranscript else { completion(false); return }
        guard hasUnsavedChanges else { completion(true); return }
        protectTranscript(true)
        let alert = NSAlert()
        alert.messageText = "\(action)前要儲存字幕嗎？"
        alert.informativeText = "本次有尚未匯出的新增或修正字幕。選擇期間會暫停更新；取消後恢復。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "儲存並\(action)")
        alert.addButton(withTitle: "不儲存，直接\(action)")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            saveTranscript(format: preferredExportFormat) { [weak self] saved in
                guard let self else { completion(false); return }
                let mayProceed = saved && !self.hasUnsavedChanges
                completion(mayProceed)
                self.protectTranscript(false)
            }
        } else {
            completion(response == .alertSecondButtonReturn)
            protectTranscript(false)
        }
    }

    func requestClearCaptions() {
        resolveUnsavedChanges(action: "清除") { [weak self] proceed in
            if proceed { self?.clearCaptions() }
        }
    }

    func clearCaptions() {
        generation += 1
        revision += 1
        // Keep rolling-snapshot alignment so unchanged old captions do not reappear.
        for unit in units { clearedSources[unit.id] = unit.text }
        units = []
        firstSeen.removeAll()
        sessionStartedAt = nil
        savedRows = []
        translations.removeAll()
        failed.removeAll()
        english = ""
        chinese = ""
        lastCaptionChangeAt = nil
        lastSuccessfulRead = nil
        diagnostics = ""
        pendingSince = nil
        exportStatus = ""
        timingStatus = "尚無翻譯耗時"
        translationStatus = configuration == nil ? "尚未準備語言模型" : "等待完整句子（. ? !）"
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func applyCaptionRead(_ read: CaptionRead, at now: Date = Date()) {
        connectionStatus = read.status
        if !read.text.isEmpty {
            lastSuccessfulRead = (now, read.text, read.diagnostics)
            if !isProtectingTranscript && read.text != english { setEnglish(read.text, at: now) }
        }
        var detail = "本次讀取 \(TranscriptService.clockLabel(now))：\(read.status)\n\(read.diagnostics)"
        if let last = lastSuccessfulRead {
            detail += "\n\n最後成功 \(TranscriptService.clockLabel(last.at))（僅記憶體）\n原始字幕：\n\(last.text)\nAX 屬性：\n\(last.details)"
        }
        diagnostics = detail
    }

    func start() {
        if sessionStartedAt == nil { sessionStartedAt = Date() }
        stop()
        running = true
        prepareTranslationIfNeeded()
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let result = await reader.read()
                guard !Task.isCancelled else { return }
                applyCaptionRead(result)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stop() {
        polling?.cancel()
        polling = nil
        running = false
        generation += 1
        revision += 1
        connectionStatus = "已停止"
    }

    func setEnglish(_ text: String, at now: Date = Date()) {
        guard !isProtectingTranscript, text != english else { return }
        if sessionStartedAt == nil { sessionStartedAt = now }
        english = text
        lastCaptionChangeAt = now
        units = processor.consume(text).filter { clearedSources[$0.id] != $0.text }
        for unit in units where firstSeen[unit.id] == nil { firstSeen[unit.id] = now }
        // Keep the last translation visible while the next snapshot is pending.
        revision += 1
        refreshChinese()
        if nextTranslationUnit != nil {
            if configuration == nil { translationStatus = "翻譯尚未啟動；開始擷取會自動準備模型" }
            if pendingSince == nil { pendingSince = now }
        } else {
            pendingSince = nil
            if units.last?.complete == false { translationStatus = "等待完整句子（. ? !）" }
        }
    }

    private var pendingTranslationUnits: [CaptionUnit] {
        units.filter { $0.complete && translations[$0.id]?.source != $0.text && failed[$0.id] != $0.text }
    }

    var pendingTranslationCount: Int { pendingTranslationUnits.count }

    func translationCandidate(prioritizeLatest: Bool) -> CaptionUnit? {
        prioritizeLatest ? pendingTranslationUnits.last : pendingTranslationUnits.first
    }

    var nextTranslationUnit: CaptionUnit? {
        // Live reading must not wait behind an entire lecture's backlog.
        // Stopping capture lets the remaining history finish in chronological order.
        translationCandidate(prioritizeLatest: running)
    }

    func shouldTranslate(at now: Date) -> Bool {
        !isProtectingTranscript && nextTranslationUnit != nil
    }

    /// Exact source matching prevents a corrected/deleted sentence accepting an old result.
    @discardableResult
    func acceptTranslation(_ result: String, for unit: CaptionUnit) -> Bool {
        guard !isProtectingTranscript, units.contains(where: { $0.id == unit.id && $0.complete && $0.text == unit.text }) else { return false }
        translations[unit.id] = (unit.text, result)
        refreshChinese()
        return true
    }

    private func refreshChinese() {
        chinese = units.compactMap { unit in
            guard unit.complete, let translation = translations[unit.id], translation.source == unit.text else { return nil }
            return translation.result
        }.joined(separator: "\n")
    }

    func prepareTranslationIfNeeded() {
        if configuration == nil { prepareTranslation() }
    }

    func prepareTranslation() {
        generation += 1
        failed.removeAll()
        if configuration == nil {
            if #available(macOS 26.4, *) {
                configuration = .init(source: AppleTranslationService.source, target: AppleTranslationService.target, preferredStrategy: .lowLatency)
            } else {
                configuration = .init(source: AppleTranslationService.source, target: AppleTranslationService.target)
            }
        } else { configuration?.invalidate() }
    }

    func runTranslation(session: TranslationSession) async {
        let service = AppleTranslationService(session: session)
        translationStatus = "檢查語言支援／準備模型…"
        do {
            try await service.prepare()
            translationStatus = "模型已準備，等待字幕"
            pendingSince = Date()
            while !Task.isCancelled {
                if shouldTranslate(at: Date()),
                   let unit = nextTranslationUnit {
                    let capturedGeneration = generation
                    let submittedAt = Date()
                    let wait = submittedAt.timeIntervalSince(pendingSince ?? submittedAt)
                    let sourceTime = firstSeen[unit.id].map { TranscriptService.clockLabel($0) } ?? "未知時間"
                    translationStatus = "翻譯 \(sourceTime) 的句子 · 待譯 \(pendingTranslationCount) 句…"
                    do {
                        let result = try await service.translate(unit.text)
                        try Task.checkCancellation()
                        if generation == capturedGeneration, acceptTranslation(result, for: unit) {
                            translationStatus = units.last?.complete == false ? "等待完整句子（. ? !）" : "翻譯完成"
                        }
                        timingStatus = String(format: "上次排程等待 %.2f 秒 · 模型翻譯 %.2f 秒 · %d 字元", wait, Date().timeIntervalSince(submittedAt), unit.text.count)
                    } catch {
                        if Task.isCancelled { return }
                        if generation == capturedGeneration && !isProtectingTranscript {
                            failed[unit.id] = unit.text
                            translationStatus = "翻譯失敗：\(error.localizedDescription)；請按準備／重試"
                        }
                    }
                    // A single consumer coalesces updates: no FIFO of obsolete snapshots.
                    pendingSince = nextTranslationUnit != nil ? (pendingSince ?? Date()) : nil
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        } catch {
            if !Task.isCancelled { translationStatus = "模型準備失敗：\(error.localizedDescription)；請重試" }
        }
    }
}

/// Literal, case/diacritic-insensitive search over both languages, one result per sentence.
enum CaptionSearch {
    static func matches(_ rows: [CaptionDisplayRow], query: String) -> [CaptionDisplayRow] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return rows.filter {
            $0.english.range(of: term, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil ||
            $0.chinese?.range(of: term, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
        }
    }

    static func movedID(in rows: [CaptionDisplayRow], currentID: Int?, step: Int) -> Int? {
        guard !rows.isEmpty else { return nil }
        let index = rows.firstIndex { $0.id == currentID } ?? (step > 0 ? -1 : 0)
        return rows[(index + step + rows.count) % rows.count].id
    }
}
