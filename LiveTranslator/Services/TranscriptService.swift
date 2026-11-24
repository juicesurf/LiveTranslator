import Foundation

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

    static func plainText(rows: [CaptionDisplayRow], exportedAt: Date) -> String {
        document(rows: rows, exportedAt: exportedAt, format: .txt)
    }

    static func document(rows: [CaptionDisplayRow], exportedAt: Date, format: TranscriptFormat) -> String {
        let date = exportedAt.formatted(date: .numeric, time: .standard)
        let note = "時間為本次擷取的經過時間，並非影片播放時間。"
        let body = rows.map { row in
            let time = elapsedLabel(row.elapsed)
            let chinese = row.chinese ?? "[\(row.status.rawValue)]"
            switch format {
            case .txt:
                return "[\(time)] [\(row.status.rawValue)]\n\(row.english)\n\(chinese)"
            case .markdown:
                return "### \(time) · \(row.status.rawValue)\n\n**English**\n\n\(escape(row.english))\n\n**繁體中文**\n\n\(escape(chinese))"
            }
        }.joined(separator: "\n\n")
        let title = format == .markdown ? "# LiveTranslator 中英逐字稿" : "LiveTranslator 中英逐字稿"
        return "\(title)\n\n匯出時間：\(date)\n\n\(note)\n\n\(body)\n"
    }

    private static func escape(_ text: String) -> String {
        let reserved = Set("\\`*_{}[]<>#+-.!|")
        return text.map { reserved.contains($0) ? "\\\($0)" : String($0) }.joined()
    }
}
