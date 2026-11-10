//
//  Localization.swift
//  Pelagica
//

import Foundation
import PelagicaI18n
import Synchronization

nonisolated let i18n = Translations()

nonisolated final class Translations: Sendable {
    static let languageDefaultsKey = "appLanguage"

    let supportedLanguages: [SupportedLanguage]
    private let localizer: Mutex<Localizer>

    init() {
        do {
            supportedLanguages = try Localizer.supportedLanguages()
            localizer = Mutex(try Self.makeLocalizer(for: UserDefaults.standard.string(forKey: Self.languageDefaultsKey)))
        } catch {
            fatalError("PelagicaI18n resources are missing from the bundle: \(error)")
        }
    }

    var languageOverride: String? {
        UserDefaults.standard.string(forKey: Self.languageDefaultsKey)
    }

    var language: String {
        localizer.withLock { $0.language }
    }

    func setLanguageOverride(_ code: String?) {
        guard let newLocalizer = try? Self.makeLocalizer(for: code) else { return }
        localizer.withLock { $0 = newLocalizer }
        // Written after the swap so views observing the key re-render with the new language
        UserDefaults.standard.set(code, forKey: Self.languageDefaultsKey)
    }

    func t(_ key: String, count: Int? = nil, _ values: [String: CustomStringConvertible] = [:]) -> String {
        localizer.withLock { $0.t(key, count: count, values) }
    }

    private static func makeLocalizer(for code: String?) throws -> Localizer {
        if let code, let localizer = try? Localizer(language: code) {
            return localizer
        }
        return try Localizer()
    }
}
