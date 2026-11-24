import AppKit

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "LiveTranslator"
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        minSize = NSSize(width: 480, height: 320)
        setFrameAutosaveName("LiveTranslatorOverlay")
        if !setFrameUsingName("LiveTranslatorOverlay") { center() }
    }

    func apply(_ settings: OverlaySettings) {
        level = settings.alwaysOnTop ? .floating : .normal
        alphaValue = settings.opacity
        switch settings.appearance {
        case .system: appearance = nil
        case .dark: appearance = NSAppearance(named: .darkAqua)
        case .light: appearance = NSAppearance(named: .aqua)
        }
    }
}
