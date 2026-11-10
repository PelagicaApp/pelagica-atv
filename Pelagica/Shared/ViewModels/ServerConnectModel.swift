//
//  ServerConnectModel.swift
//  Pelagica
//

import Combine
import Foundation
import JellyfinAPI

@MainActor
final class ServerConnectModel: ObservableObject {
    @Published var address = ""
    @Published private(set) var isConnecting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var discoveredServers: [JellyfinClient.PublicServer] = []

    var canConnect: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty && !isConnecting
    }

    /// Collects servers announcing themselves on the local network until the task is cancelled.
    func discoverServers() async {
        do {
            for try await server in JellyfinClient.discover() {
                if !discoveredServers.contains(server) {
                    discoveredServers.append(server)
                }
            }
        } catch {
        }
    }

    /// Resolves the typed address, returning nil and setting `errorMessage` when no server answers.
    func connect(appState: AppState) async -> DiscoveredServer? {
        guard canConnect else { return nil }
        errorMessage = nil
        isConnecting = true
        defer { isConnecting = false }
        do {
            return try await appState.resolveServer(fromInput: address)
        } catch {
            errorMessage = i18n.t("login:could_not_find_server")
            return nil
        }
    }
}
