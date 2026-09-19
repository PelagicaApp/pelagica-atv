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
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var activeProfile: Profile?
    @Published private(set) var isAddingProfile = false
    @Published private(set) var reauthServer: DiscoveredServer?
    
    private let keychain = KeychainStore()
    private let defaults = UserDefaults.standard
    
    private enum DefaultsKey {
        static let profiles = "pelagica.profiles"
        static let deviceID = "pelagica.deviceID"
        
        // Single Session storage from before profiles existed. Only read for migration
        static let legacyServerURL = "pelagica.serverURL"
        static let legacyServerName = "pelagica.serverName"
    }
    
    init() {
        if let data = defaults.data(forKey: DefaultsKey.profiles),
           let saved = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = saved
        }
    }
    
    var isLoggedIn: Bool {
        client?.accessToken != nil && currentUser != nil
    }
    
    var showsProfilePicker: Bool {
        !isLoggedIn && !profiles.isEmpty && !isAddingProfile
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
        
        if trimmed.contains("://") {
            guard let url = URL(string: trimmed), url.host != nil else {
                throw ConnectionError.invalidAddress
            }
            return try await fetchServerInfo(url: url)
        }
        
        guard let httpsURL = URL(string: "https://\(trimmed)"), httpsURL.host != nil,
              let httpURL = URL(string: "http://\(trimmed)") else {
            throw ConnectionError.invalidAddress
        }
        
        return try await withThrowingTaskGroup(of: DiscoveredServer.self) { group in
            for url in [httpsURL, httpURL] {
                group.addTask {
                    do {
                        return try await self.fetchServerInfo(url: url)
                    } catch {
                        print("Pelagica connect: \(url.absoluteString) failed: \(error)")
                        throw error
                    }
                }
            }
            
            var lastError: Error = ConnectionError.invalidAddress
            while true {
                do {
                    guard let server = try await group.next() else { throw lastError }
                    group.cancelAll()
                    return server
                } catch {
                    lastError = error
                    if group.isEmpty { throw error }
                }
            }
        }
    }
    
    func fetchServerInfo(url: URL) async throws -> DiscoveredServer {
        let probeClient = JellyfinClient(configuration: makeConfiguration(url: url))
        let info = try await probeClient.send(Paths.getPublicSystemInfo).value
        return DiscoveredServer(name: info.serverName ?? url.host ?? url.absoluteString, url: url)
    }
    
    func signIn(server: DiscoveredServer, username: String, password: String) async throws {
        let newClient = JellyfinClient(configuration: makeConfiguration(url: server.url))
        let result = try await newClient.signIn(username: username, password: password)
        try completeSignIn(client: newClient, result: result, server: server)
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
        try completeSignIn(client: newClient, result: result, server: server)
    }
    
    // MARK: - Profiles
    
    func profileImageURL(for profile: Profile) -> URL? {
        guard let tag = profile.imageTag else { return nil }
        let request = Paths.getUserImage(parameters: Paths.GetUserImageParameters(userID: profile.userID, tag: tag))
        return JellyfinClient(configuration: makeConfiguration(url: profile.serverURL)).url(with: request)
    }
    
    func restoreSession() async {
        defer { isRestoringSession = false }
        
        await migrateLegacySession()
        
        // With several profiles the user chooses; with exactly one we sign straight back in.
        if profiles.count == 1, let profile = profiles.first {
            try? await selectProfile(profile)
        }
    }
    
    /// Signs in with a profile's stored token. Throws if the server can't be reached; if the token
    /// is missing or rejected, routes to the login flow for that profile's server instead.
    func selectProfile(_ profile: Profile) async throws {
        guard let token = keychain.readToken(forAccount: profile.id.uuidString) else {
            beginReauth(for: profile)
            return
        }
        
        let restoredClient = JellyfinClient(configuration: makeConfiguration(url: profile.serverURL, accessToken: token))
        
        do {
            let user = try await restoredClient.send(Paths.getCurrentUser).value
            activate(profile, client: restoredClient, user: user)
        } catch {
            guard isUnauthorized(error) else { throw error }
            keychain.deleteToken(forAccount: profile.id.uuidString)
            beginReauth(for: profile)
        }
    }
    
    func beginAddingProfile() {
        reauthServer = nil
        isAddingProfile = true
    }
    
    func cancelAddingProfile() {
        reauthServer = nil
        isAddingProfile = false
    }
    
    /// Leaves the current profile signed in on the server, and returns to the profile picker.
    func switchProfile() {
        client = nil
        currentUser = nil
        serverName = nil
        activeProfile = nil
        isAddingProfile = false
        reauthServer = nil
    }
    
    /// Signs the current profile out of its server and forgets it.
    func signOut() {
        guard let profile = activeProfile else { return }
        let signedOutClient = client
        switchProfile()
        forget(profile)
        
        Task {
            try? await signedOutClient?.signOut()
        }
    }
    
    /// Forgets a profile without needing it to be active. The server session is revoked best-effort.
    func removeProfile(_ profile: Profile) {
        let token = keychain.readToken(forAccount: profile.id.uuidString)
        forget(profile)
        
        guard let token else { return }
        let staleClient = JellyfinClient(configuration: makeConfiguration(url: profile.serverURL, accessToken: token))
        Task {
            try? await staleClient.signOut()
        }
    }
    
    private func forget(_ profile: Profile) {
        keychain.deleteToken(forAccount: profile.id.uuidString)
        profiles.removeAll { $0.id == profile.id }
        persistProfiles()
    }
    
    private func beginReauth(for profile: Profile) {
        reauthServer = profile.server
        isAddingProfile = true
    }
    
    private func isUnauthorized(_ error: Error) -> Bool {
        if let apiError = error as? APIError, case .unacceptableStatusCode(401) = apiError {
            return true
        }
        return false
    }
    
    /// Saves (or refreshes) the profile for a completed sign-in and makes it the active one.
    private func completeSignIn(client newClient: JellyfinClient, result: AuthenticationResult, server: DiscoveredServer) throws {
        guard let user = result.user, let userID = user.id, let token = result.accessToken else {
            throw ConnectionError.noAccessToken
        }
        
        let profile = profiles.first { $0.serverURL == server.url && $0.userID == userID }
            ?? Profile(id: UUID(), serverURL: server.url, serverName: server.name, userID: userID, userName: user.name ?? "Unknown")
        
        keychain.saveToken(token, forAccount: profile.id.uuidString)
        activate(profile, client: newClient, user: user, serverName: server.name)
    }
    
    /// Makes a profile current, refreshing its cached details from the server's view of the user.
    private func activate(_ profile: Profile, client newClient: JellyfinClient, user: UserDto, serverName newServerName: String? = nil) {
        var profile = profile
        profile.userName = user.name ?? profile.userName
        profile.imageTag = user.primaryImageTag
        if let newServerName { profile.serverName = newServerName }
        
        profiles.removeAll { $0.id == profile.id }
        profiles.insert(profile, at: 0)
        persistProfiles()
        
        client = newClient
        currentUser = user
        serverName = profile.serverName
        activeProfile = profile
        isAddingProfile = false
        reauthServer = nil
    }
    
    private func persistProfiles() {
        defaults.set(try? JSONEncoder().encode(profiles), forKey: DefaultsKey.profiles)
    }
    
    /// Turns the pre-profiles single session (server URL in defaults, token keyed by URL) into a profile.
    private func migrateLegacySession() async {
        guard let urlString = defaults.string(forKey: DefaultsKey.legacyServerURL) else { return }
        
        func clearLegacy() {
            keychain.deleteToken(forAccount: urlString)
            defaults.removeObject(forKey: DefaultsKey.legacyServerURL)
            defaults.removeObject(forKey: DefaultsKey.legacyServerName)
        }
        
        guard let url = URL(string: urlString), let token = keychain.readToken(forAccount: urlString) else {
            clearLegacy()
            return
        }
        
        let legacyClient = JellyfinClient(configuration: makeConfiguration(url: url, accessToken: token))
        
        do {
            let user = try await legacyClient.send(Paths.getCurrentUser).value
            guard let userID = user.id else { return }
            
            let profile = Profile(
                id: UUID(),
                serverURL: url,
                serverName: defaults.string(forKey: DefaultsKey.legacyServerName) ?? url.host ?? urlString,
                userID: userID,
                userName: user.name ?? "Unknown",
                imageTag: user.primaryImageTag
            )
            keychain.saveToken(token, forAccount: profile.id.uuidString)
            profiles.append(profile)
            persistProfiles()
            clearLegacy()
        } catch {
            // Keep the legacy session for the next launch unless the server has rejected it.
            if isUnauthorized(error) { clearLegacy() }
        }
    }
}
