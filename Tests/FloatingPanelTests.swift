import AppKit
import Testing
@testable import LiveTranslatorCore

@MainActor
struct FloatingPanelTests {
    @Test func panelRemainsNonactivatingWhenSettingsChange() {
        let panel = FloatingPanel()
        defer { panel.close() }
        let settings = OverlaySettings()
        panel.apply(settings)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.resizable))
        #expect(!panel.hidesOnDeactivate)
        #expect(panel.becomesKeyOnlyIfNeeded)
        #expect(!panel.canBecomeMain)
        #expect(panel.level == .floating)
        settings.alwaysOnTop = false
        settings.opacity = 0.7
        settings.appearance = .light
        panel.apply(settings)
        #expect(panel.level == .normal)
        #expect(panel.alphaValue == 0.7)
        #expect(panel.appearance?.name == .aqua)
        #expect(!panel.isVisible)
        #expect(!panel.isKeyWindow)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }
}
