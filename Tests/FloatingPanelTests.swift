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

@MainActor
struct NotesModeTests {
    @Test func switchingModesPreservesSubtitlePreferencesAndWindowBehavior() {
        let settings = OverlaySettings()
        settings.englishFontSize = 20
        settings.chineseFontSize = 30
        settings.chineseOnly = true
        settings.opacity = 0.8
        let panel = FloatingPanel()
        defer { panel.close() }
        settings.mode = .notes
        panel.apply(settings)
        #expect(settings.activeEnglishSize == 14)
        #expect(settings.activeChineseSize == 14)
        #expect(panel.level == .normal)
        #expect(panel.title == "筆記")
        #expect(panel.alphaValue == 1)
        #expect(panel.appearance?.name == .aqua)
        #expect(!panel.isKeyWindow)
        settings.mode = .subtitles
        panel.apply(settings)
        #expect(panel.level == .floating)
        #expect(settings.activeEnglishSize == 20)
        #expect(settings.activeChineseSize == 30)
        #expect(settings.chineseOnly)
        #expect(panel.alphaValue == 0.8)
        #expect(panel.appearance?.name == .darkAqua)
    }
}
