//
//  AppConfigStore.swift
//  Pelagica
//

import Combine
import Foundation
import JellyfinAPI

@MainActor
final class AppConfigStore: ObservableObject {
    @Published private(set) var config: AppConfig = .fallback
    @Published private(set) var isLoading = true

    func load(client: JellyfinClient) async {
        config = await PelagicaPluginAPI.fetchConfig(serverURL: client.configuration.url)
        isLoading = false
    }
}
