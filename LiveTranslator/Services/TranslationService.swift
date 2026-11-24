import Foundation

@MainActor
protocol TranslationService {
    func prepare() async throws
    func translate(_ text: String) async throws -> String
}
