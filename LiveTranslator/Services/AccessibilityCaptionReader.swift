import AppKit
import ApplicationServices

struct CaptionRead: Sendable {
    var text: String = ""
    var status: String
    var diagnostics: String = ""
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
        var caption: String?
        var inCaptionArea = false
        var diagnostics: [String] = []
        var visited = 0
        while !nodes.isEmpty && visited < 300 {
            let node = nodes.removeFirst()
            visited += 1
            let role = string(node, kAXRoleAttribute)
            if role == kAXScrollAreaRole && !inCaptionArea {
                // The verified source is Static Text inside the caption scroll area.
                // Do not concatenate every static label in the process (controls/history overlap).
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
                    caption = text
                    break
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] { nodes.append(contentsOf: children) }
        }
        return CaptionRead(text: caption ?? "",
                           status: caption == nil ? "已連線，等待字幕（或 AX 尚未就緒）" : "正在擷取英文字幕",
                           diagnostics: diagnostics.joined(separator: "\n"))
    }

    private func string(_ element: AXUIElement, _ key: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
