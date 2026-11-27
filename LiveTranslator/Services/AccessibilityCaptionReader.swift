import AppKit
import ApplicationServices

struct CaptionRead: Sendable {
    var text: String = ""
    var status: String
    var diagnostics: String = ""
}

enum CaptionTextSelector {
    static func latest(from texts: [String]) -> String? {
        let controls: Set<String> = ["已暫停", "暫停", "Paused", "Live Captions", "即時字幕"]
        return texts.reversed().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !controls.contains($0) }
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
        var nodes = [root]
        var captionTexts: [String] = []
        var inCaptionArea = false
        var diagnostics: [String] = []
        var visited = 0
        while !nodes.isEmpty && visited < 300 {
            let node = nodes.removeLast()
            visited += 1
            let role = string(node, kAXRoleAttribute)
            if role == kAXScrollAreaRole && !inCaptionArea {
                // Isolate the caption scroll area, excluding the surrounding controls.
                // Traverse its children in AX order to select the newest (last) text block.
                nodes.removeAll()
                inCaptionArea = true
            }
            if inCaptionArea && role == kAXStaticTextRole {
                // AppleScript's name mapping varies. Inspect all candidate AX attributes.
                let candidates = [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute]
                let values = candidates.compactMap { key -> (String, String)? in
                    guard let value = string(node, key), !value.isEmpty else { return nil }
                    return (key, value)
                }
                diagnostics.append(values.map { "\($0.0): \($0.1)" }.joined(separator: " | "))
                if let text = values.first?.1 {
                    captionTexts.append(text)
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] { nodes.append(contentsOf: children.reversed()) }
        }
        let caption = CaptionTextSelector.latest(from: captionTexts)
        return CaptionRead(text: caption ?? "",
                           status: caption == nil ? "已連線，等待字幕（或 AX 尚未就緒）" : "正在擷取英文字幕（\(captionTexts.count) 個文字節點，讀取最新一個）",
                           diagnostics: "字幕文字節點數：\(captionTexts.count)\n" + diagnostics.suffix(5).joined(separator: "\n"))
    }

    private func string(_ element: AXUIElement, _ key: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
