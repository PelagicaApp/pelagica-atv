//
//  SubtitleStyleStore.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI

@MainActor
final class SubtitleStyleStore: ObservableObject {
    @Published private(set) var style: SubtitleStyle = .default

    private static let displayPreferencesID = "usersettings"
    private static let preferencesClient = "pelagica"
    private static let customPrefsKey = "subtitleStyle"
    private static let defaultsKeyPrefix = "subtitleStyle."

    private let defaults = UserDefaults.standard
    private var client: JellyfinClient?
    private var userID: String?
    private var editGeneration = 0

    func load(client: JellyfinClient, userID: String?) async {
        self.client = client
        self.userID = userID
        guard let userID else { return }
        if let cached = cachedStyle(for: userID) {
            style = cached
        }

        let generation = editGeneration
        do {
            let preferences = try await client.send(Paths.getDisplayPreferences(
                displayPreferencesID: Self.displayPreferencesID,
                userID: userID,
                client: Self.preferencesClient
            )).value
            guard generation == editGeneration, self.userID == userID else { return }
            guard let json = preferences.customPrefs?[Self.customPrefsKey],
                  let remote = try? JSONDecoder().decode(SubtitleStyle.self, from: Data(json.utf8)) else { return }
            style = remote
            cache(remote, for: userID)
        } catch {
            print("Pelagica: failed to load subtitle style: \(error)")
        }
    }

    func update(_ change: (inout SubtitleStyle) -> Void) {
        var newStyle = style
        change(&newStyle)
        guard newStyle != style else { return }
        style = newStyle
        editGeneration += 1
        guard let userID else { return }
        cache(newStyle, for: userID)
        Task { await save(newStyle, userID: userID) }
    }

    func reset() {
        update { $0 = .default }
    }

    // MARK: - Server

    private func save(_ style: SubtitleStyle, userID: String) async {
        guard let client, let data = try? JSONEncoder().encode(style), let json = String(data: data, encoding: .utf8) else { return }
        do {
            var preferences = try await client.send(Paths.getDisplayPreferences(
                displayPreferencesID: Self.displayPreferencesID,
                userID: userID,
                client: Self.preferencesClient
            )).value
            guard style == self.style else { return }
            var customPrefs = preferences.customPrefs ?? [:]
            customPrefs[Self.customPrefsKey] = json
            preferences.customPrefs = customPrefs
            try await client.send(Paths.updateDisplayPreferences(
                displayPreferencesID: Self.displayPreferencesID,
                userID: userID,
                client: Self.preferencesClient,
                preferences
            ))
        } catch {
            print("Pelagica: failed to save subtitle style: \(error)")
        }
    }

    // MARK: - Cache

    private func cachedStyle(for userID: String) -> SubtitleStyle? {
        guard let data = defaults.data(forKey: Self.defaultsKeyPrefix + userID) else { return nil }
        return try? JSONDecoder().decode(SubtitleStyle.self, from: data)
    }

    private func cache(_ style: SubtitleStyle, for userID: String) {
        defaults.set(try? JSONEncoder().encode(style), forKey: Self.defaultsKeyPrefix + userID)
    }
}
