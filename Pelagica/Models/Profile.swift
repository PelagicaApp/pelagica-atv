//
//  Profile.swift
//  Pelagica
//

import Foundation

/// A saved profile: one user on one server. The access token lives in the Keychain, keyed by `id`.
struct Profile: Identifiable, Codable, Hashable {
    let id: UUID
    var serverURL: URL
    var serverName: String
    var userID: String
    var userName: String
    var imageTag: String?

    var server: DiscoveredServer {
        DiscoveredServer(name: serverName, url: serverURL)
    }
}
