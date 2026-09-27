//
//  Localization.swift
//  Pelagica
//

import PelagicaI18n

nonisolated let i18n = Translations()

nonisolated struct Translations: Sendable {
    private let localizer: Localizer

    init() {
        do {
            localizer = try Localizer()
        } catch {
            fatalError("PelagicaI18n resources are missing from the bundle: \(error)")
        }
    }

    func t(_ key: String, count: Int? = nil, _ values: [String: CustomStringConvertible] = [:]) -> String {
        localizer.t(key, count: count, values)
    }
}
