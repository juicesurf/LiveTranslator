import AppKit
import ApplicationServices

struct CaptionRead: Sendable {
    var text: String = ""
    var status: String
    var diagnostics: String = ""
}

enum CaptionTextSelector {
    private static let controls: Set<String> = ["已暫停", "暫停", "Paused", "Live Captions", "即時字幕"]

    private static func valid(_ texts: [String]) -> [String] {
        texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !controls.contains($0) }
    }

    static func latest(from texts: [String]) -> String? { valid(texts).last }

    /// Include the preceding block so its late punctuation/corrections remain observable.
    /// Never join labels outside a caption scroll area, or globally remove repeated sentences.
    static func snapshot(from texts: [String]) -> String? {
        let recent = Array(valid(texts).suffix(2))
        guard let newest = recent.last else { return nil }
        guard recent.count == 2 else { return newest }
        let old = recent[0].split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let new = newest.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        func key(_ word: String) -> String { word.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        let oldKeys = old.map(key)
        let newKeys = new.map(key)
        // Some AX nodes expose an overlapping expanded version of a preceding block.
        if new.count > old.count, Array(newKeys.prefix(old.count)) == oldKeys { return newest }
        if min(old.count, new.count) >= 3, oldKeys != newKeys {
            for count in stride(from: min(old.count, new.count), through: 3, by: -1) {
                if Array(oldKeys.suffix(count)) == Array(newKeys.prefix(count)) {
                    return (Array(old.dropLast(count)) + new).joined(separator: " ")
                }
            }
        }
        return recent.joined(separator: "\n")
    }

    static func snapshot(fromAreas areas: [[String]]) -> String? {
        areas.lazy.compactMap { snapshot(from: $0) }.first
    }
}

/// AX calls run on this actor, away from the main actor. No AX objects cross its boundary.
actor AccessibilityCaptionReader {
    static let executablePath = "/System/Library/PrivateFrameworks/AccessibilitySharedSupport.framework/Versions/A/Resources/Live Captions.app/Contents/MacOS/Live Captions"

    func read() -> CaptionRead {
        guard AXIsProcessTrusted() else { return CaptionRead(status: "需要輔助使用權限") }
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.executableURL?.path == Self.executablePath
        }) else { return CaptionRead(status: "等待 Live Captions 開啟") }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.2)
        var windowValue: CFTypeRef?
        let windowsError = AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &windowValue)
        let windows = windowValue as? [AXUIElement] ?? []
        var nodes: [(element: AXUIElement, area: Int?)] = (windows.isEmpty ? [root] : windows).reversed().map { ($0, nil) }
        var textsByArea: [[String]] = []
        var detailsByArea: [[String]] = []
        var visited = 0
        var readErrors = 0
        while !nodes.isEmpty && visited < 300 {
            let item = nodes.removeLast()
            let node = item.element
            visited += 1
            let role = string(node, kAXRoleAttribute)
            var area = item.area
            if role == kAXScrollAreaRole && area == nil {
                area = textsByArea.count
                textsByArea.append([])
                detailsByArea.append([])
            }
            if let area, role == kAXStaticTextRole {
                let values = [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute].compactMap { key -> (String, String)? in
                    guard let value = string(node, key), !value.isEmpty else { return nil }
                    return (key, value)
                }
                detailsByArea[area].append(values.map { "\($0.0): \($0.1)" }.joined(separator: " | "))
                if let text = values.first?.1 { textsByArea[area].append(text) }
            }
            var children: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &children)
            if error == .success, let children = children as? [AXUIElement] {
                nodes.append(contentsOf: children.reversed().map { ($0, area) })
            } else if error != .attributeUnsupported && error != .noValue { readErrors += 1 }
        }
        // An empty scroll area must not hide another window/area containing actual captions.
        let selected = textsByArea.indices.first { CaptionTextSelector.snapshot(from: textsByArea[$0]) != nil }
        let caption = selected.flatMap { CaptionTextSelector.snapshot(from: textsByArea[$0]) }
        let count = selected.map { textsByArea[$0].count } ?? 0
        let detail = selected.map { detailsByArea[$0].suffix(4).joined(separator: "\n") } ?? ""
        let trace = "視窗：\(windows.count)（AX結果 \(windowsError.rawValue)） · 捲動區：\(textsByArea.count) · 遍歷節點：\(visited) · 讀取錯誤：\(readErrors)\n字幕文字節點數：\(count)\n\(detail)"
        return CaptionRead(text: caption ?? "",
            status: caption == nil ? "已連線，未讀到字幕；持續重試中" : "正在擷取英文字幕（\(count) 個文字節點，核對最後兩個）",
            diagnostics: trace)
    }

    private func string(_ element: AXUIElement, _ key: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
