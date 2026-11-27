import Observation

@MainActor @Observable
final class OverlaySettings {
    var mode = OverlayMode.subtitles
    var notesAlwaysOnTop = false
    var isNotes: Bool { mode == .notes }
    var activeAlwaysOnTop: Bool {
        get { isNotes ? notesAlwaysOnTop : alwaysOnTop }
        set { if isNotes { notesAlwaysOnTop = newValue } else { alwaysOnTop = newValue } }
    }
    var activeAppearance: OverlayAppearance { isNotes ? .light : appearance }
    var activeOpacity: Double { isNotes ? 1 : opacity }
    var activeEnglishSize: Double { isNotes ? 14 : englishFontSize }
    var activeChineseSize: Double { isNotes ? 14 : chineseFontSize }
    var alwaysOnTop = true
    var chineseOnly = false
    var englishFontSize = 16.0
    var chineseFontSize = 23.0
    var opacity = 0.95
    var appearance = OverlayAppearance.dark
}

enum OverlayAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "跟隨系統"
        case .light: "淺色"
        case .dark: "深色"
        }
    }
}

enum OverlayMode: String, CaseIterable, Identifiable {
    case subtitles, notes
    var id: String { rawValue }
    var title: String { self == .subtitles ? "雙語字幕" : "雙語筆記" }
}
