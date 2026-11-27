import Foundation
import AppKit

enum TranscriptFormat: String, CaseIterable {
    case txt, markdown
    var fileExtension: String { self == .txt ? "txt" : "md" }
    var title: String { self == .txt ? "TXT" : "Markdown" }
}

enum CaptionStatus: String {
    case incomplete = "英文未完成"
    case pending = "待翻譯"
    case translated = "已翻譯"
    case failed = "翻譯失敗"
}

struct TranscriptService {
    static func elapsedLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    static func calendarDate(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func clockLabel(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent, includeDate: Bool = false) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let clock = String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
        return includeDate ? "\(calendarDate(date, timeZone: timeZone)) \(clock)" : clock
    }

    static func plainText(rows: [CaptionDisplayRow], exportedAt: Date) -> String {
        document(rows: rows, exportedAt: exportedAt, format: .txt)
    }

    static func document(rows: [CaptionDisplayRow], exportedAt: Date, format: TranscriptFormat, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let date = clockLabel(exportedAt, timeZone: timeZone, includeDate: true)
        let days = Set(rows.map { calendarDate($0.timestamp, timeZone: timeZone) }).sorted()
        let offsets = Set(rows.map { timeZone.secondsFromGMT(for: $0.timestamp) })
        let note = "第一個時間為擷取經過時間，第二個為首次擷取的當地真實時間，並非影片播放時間。"
        let metadata = "擷取日期：\(days.joined(separator: "、"))\n\n時區：\(timeZone.identifier)"
        let body = rows.map { row in
            let time = elapsedLabel(row.elapsed)
            var actual = clockLabel(row.timestamp, timeZone: timeZone, includeDate: days.count > 1)
            if offsets.count > 1 {
                let offset = timeZone.secondsFromGMT(for: row.timestamp)
                actual += String(format: " UTC%@%02d:%02d", offset < 0 ? "-" : "+", abs(offset) / 3600, abs(offset) / 60 % 60)
            }
            let chinese = row.chinese ?? "[\(row.status.rawValue)]"
            switch format {
            case .txt:
                return "[\(time)] [\(actual)] [\(row.status.rawValue)]\n\(row.english)\n\(chinese)"
            case .markdown:
                return "### \(time) · \(actual) · \(row.status.rawValue)\n\n**English**\n\n\(escape(row.english))\n\n**繁體中文**\n\n\(escape(chinese))"
            }
        }.joined(separator: "\n\n")
        let title = format == .markdown ? "# LiveTranslator 中英逐字稿" : "LiveTranslator 中英逐字稿"
        return "\(title)\n\n匯出時間：\(date)\n\n\(metadata)\n\n\(note)\n\n\(body)\n"
    }

    static func escape(_ text: String) -> String {
        let reserved = Set("\\`*_{}[]<>#+-.!|")
        return text.map { reserved.contains($0) ? "\\\($0)" : String($0) }.joined()
    }
}

@MainActor
enum SavePanelPresenter {
    static func present(_ panel: NSSavePanel, from window: NSWindow?, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        // Save is an explicit user action. A modal-level sheet must sit above floating captions.
        panel.level = .modalPanel
        NSApp.activate()
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }
}
