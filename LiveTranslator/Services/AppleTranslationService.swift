import Foundation
@preconcurrency import Translation

@MainActor
final class AppleTranslationService: TranslationService {
    static let source = Locale.Language(identifier: "en")
    static let target = Locale.Language(identifier: "zh-Hant")
    private let session: TranslationSession

    init(session: TranslationSession) { self.session = session }

    func prepare() async throws {
        let availability: LanguageAvailability
        if #available(macOS 26.4, *) {
            availability = LanguageAvailability(preferredStrategy: .lowLatency)
        } else { availability = LanguageAvailability() }
        let status = await availability.status(from: Self.source, to: Self.target)
        guard status != .unsupported else { throw ServiceError.unsupported }
        try await session.prepareTranslation()
    }

    func translate(_ text: String) async throws -> String {
        try await session.translate(text).targetText
    }

    enum ServiceError: LocalizedError {
        case unsupported
        var errorDescription: String? { "系統不支援英文至繁體中文翻譯。未使用外部服務。" }
    }
}
