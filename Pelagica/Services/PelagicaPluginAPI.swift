//
//  PelagicaPluginAPI.swift
//  Pelagica
//

import Foundation

enum PelagicaPluginAPI {
    static func fetchHomeScreenConfig(serverURL: URL) async -> HomeScreenConfig {
        let url = serverURL.appendingPathComponent("Pelagica").appendingPathComponent("Config")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .fallback
            }
            return try JSONDecoder().decode(HomeScreenConfig.self, from: data)
        } catch {
            return .fallback
        }
    }
}
