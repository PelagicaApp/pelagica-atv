//
//  AppState.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoveredServer: Hashable {
    let name: String
    let url: URL
}

enum AuthRoute: Hashable {
    case loginMethod(DiscoveredServer)
    case login(DiscoveredServer)
    case quickConnect(DiscoveredServer)
}

enum ConnectionError: LocalizedError {
    case invalidAddress
    case noAccessToken

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            "Enter a valid server address."
        case .noAccessToken:
            "The server did not return an access token."
        }
    }
}

struct QuickConnectInitResult: Hashable {
    let code: String
    let secret: String
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var client: JellyfinClient?
    @Published private(set) var currentUser: UserDto?
    @Published private(set) var serverName: String?
    @Published private(set) var isRestoringSession = true
    
    private let keychain = KeychainStore()
    private let defaults = UserDefaults.standard
    
    private enum DefaultsKey {
        static let serverURL = "pelagica.serverURL"
        static let serverName = "pelagica.serverName"
        static let deviceID = "pelagica.deviceID"
    }
    
    var isLoggedIn: Bool {
        client?.accessToken != nil && currentUser != nil
    }
    
    private var deviceID: String {
        if let existing = defaults.string(forKey: DefaultsKey.deviceID) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: DefaultsKey.deviceID)
        return generated
    }
    
    private var deviceName: String {
#if canImport(UIKit)
        UIDevice.current.name
#else
        "Apple TV"
#endif
    }
    
    private func makeConfiguration(url: URL, accessToken: String? = nil) -> JellyfinClient.Configuration {
        .init(
            url: url,
            accessToken: accessToken,
            client: "Pelagica tvOS",
            deviceName: deviceName,
            deviceID: deviceID,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }
    
    /// Normalizes user input into a server URL and confirms it's reachable.
    func resolveServer(fromInput input: String) async throws -> DiscoveredServer {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ConnectionError.invalidAddress }
        
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: normalized), url.host != nil else {
            throw ConnectionError.invalidAddress
        }
        
        return try await fetchServerInfo(url: url)
    }
    
    func fetchServerInfo(url: URL) async throws -> DiscoveredServer {
        let probeClient = JellyfinClient(configuration: makeConfiguration(url: url))
        let info = try await probeClient.send(Paths.getPublicSystemInfo).value
        return DiscoveredServer(name: info.serverName ?? url.host ?? url.absoluteString, url: url)
    }
    
    func signIn(server: DiscoveredServer, username: String, password: String) async throws {
        let newClient = JellyfinClient(configuration: makeConfiguration(url: server.url))
        let result = try await newClient.signIn(username: username, password: password)
        
        guard let user = result.user, let token = result.accessToken else {
            throw ConnectionError.noAccessToken
        }
        
        client = newClient
        currentUser = user
        serverName = server.name
        
        keychain.saveToken(token, forServer: server.url)
        defaults.set(server.url.absoluteString, forKey: DefaultsKey.serverURL)
        defaults.set(server.name, forKey: DefaultsKey.serverName)
    }
    
    func initiateQuickConnect(server: DiscoveredServer) async throws -> QuickConnectInitResult? {
        let newClient = JellyfinClient(configuration: makeConfiguration(url: server.url))
        let result = try await newClient.send(Paths.initiateQuickConnect).value
        guard let resultCode = result.code, let resultSecret = result.secret else { return nil }
        return QuickConnectInitResult(code: resultCode, secret: resultSecret)
    }
    
    func checkQuickConnectStatus(server: DiscoveredServer, secret: String) async throws -> Bool {
        let newClient = JellyfinClient(configuration: makeConfiguration(url: server.url))
        let result = try await newClient.send(Paths.getQuickConnectState(secret: secret)).value
        guard let isAuthenticated = result.isAuthenticated else { return false }
        return isAuthenticated
    }
    
    func authenticateQuickConnect(server: DiscoveredServer, secret: String) async throws {
        let newClient = JellyfinClient(configuration: makeConfiguration(url: server.url))
        let result = try await newClient.signIn(quickConnectSecret: secret)

        guard let user = result.user, let token = result.accessToken else {
            throw ConnectionError.noAccessToken
        }

        client = newClient
        currentUser = user
        serverName = server.name

        keychain.saveToken(token, forServer: server.url)
        defaults.set(server.url.absoluteString, forKey: DefaultsKey.serverURL)
        defaults.set(server.name, forKey: DefaultsKey.serverName)
    }

    func restoreSession() async {
        defer { isRestoringSession = false }

        guard
            let urlString = defaults.string(forKey: DefaultsKey.serverURL),
            let url = URL(string: urlString),
            let token = keychain.readToken(forServer: url)
        else { return }

        let restoredClient = JellyfinClient(configuration: makeConfiguration(url: url, accessToken: token))

        do {
            let user = try await restoredClient.send(Paths.getCurrentUser).value
            client = restoredClient
            currentUser = user
            serverName = defaults.string(forKey: DefaultsKey.serverName) ?? url.host
        } catch {
            keychain.deleteToken(forServer: url)
        }
    }

    func signOut() {
        let signedOutClient = client
        client = nil
        currentUser = nil
        serverName = nil

        if let url = signedOutClient?.configuration.url {
            keychain.deleteToken(forServer: url)
        }
        defaults.removeObject(forKey: DefaultsKey.serverURL)
        defaults.removeObject(forKey: DefaultsKey.serverName)

        Task {
            try? await signedOutClient?.signOut()
        }
    }
}
