import Observation

@MainActor @Observable
final class OverlaySettings {
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
