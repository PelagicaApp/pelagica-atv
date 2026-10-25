//
//  SeerrStore.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI

/// Seerr session cookies, one per profile.
enum SeerrSessionStore {
    private static let keychain = KeychainStore(service: "app.pelagica.atv.Pelagica.seerrSession")

    static func session(for profileID: UUID) -> String? {
        keychain.readToken(forAccount: profileID.uuidString)
    }

    static func save(_ session: String, for profileID: UUID) {
        keychain.saveToken(session, forAccount: profileID.uuidString)
    }

    static func delete(for profileID: UUID) {
        keychain.deleteToken(forAccount: profileID.uuidString)
        setAutoLoginDisabled(false, for: profileID)
    }

    /// Set when the user logs out of Seerr themselves
    static func isAutoLoginDisabled(for profileID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: autoLoginDisabledKey(profileID))
    }

    static func setAutoLoginDisabled(_ disabled: Bool, for profileID: UUID) {
        UserDefaults.standard.set(disabled ? true : nil, forKey: autoLoginDisabledKey(profileID))
    }

    private static func autoLoginDisabledKey(_ profileID: UUID) -> String {
        "seerrAutoLoginDisabled.\(profileID.uuidString)"
    }
}

@MainActor
final class SeerrStore: ObservableObject {
    @Published private(set) var api: SeerrAPI?
    @Published private(set) var user: SeerrUser?
    @Published private(set) var isReady = false

    private(set) var seerrURL: String?
    private var profileID: UUID?
    private var jellyfin: JellyfinClient?
    private var validationTask: Task<Void, Never>?
    private var autoLoginTask: Task<Void, Never>?

    var isConfigured: Bool { seerrURL != nil }
    var isLoggedIn: Bool { api != nil }

    func configure(seerrURL rawURL: String?, profileID: UUID?, jellyfin: JellyfinClient?, pendingLogin: Task<Void, Never>?) async {
        let seerrURL = rawURL.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        self.jellyfin = jellyfin
        defer { isReady = true }
        guard isReady == false || seerrURL != self.seerrURL || profileID != self.profileID else { return }

        await pendingLogin?.value

        self.seerrURL = seerrURL
        self.profileID = profileID
        validationTask?.cancel()
        autoLoginTask?.cancel()
        autoLoginTask = nil
        user = nil
        api = nil

        guard let seerrURL, let profileID else { return }
        guard let session = SeerrSessionStore.session(for: profileID) else {
            Task { await autoLogin() }
            return
        }
        api = SeerrAPI(seerrURL: seerrURL, session: session)
        validationTask = Task { await validateSession() }
    }

    func login(username: String, password: String) async throws {
        guard let seerrURL, let profileID else { throw SeerrAPIError.invalidURL }
        let session = try await SeerrAPI.login(seerrURL: seerrURL, username: username, password: password)
        await activate(session: session, seerrURL: seerrURL, profileID: profileID)
    }

    func supportsQuickConnect() async -> Bool {
        guard let seerrURL, let jellyfin else { return false }
        async let seerrSupported = SeerrAPI.supportsQuickConnect(seerrURL: seerrURL)
        guard let data = try? await jellyfin.send(Paths.getQuickConnectEnabled).value,
              (try? JSONDecoder().decode(Bool.self, from: data)) == true
        else { return false }
        return await seerrSupported
    }

    func loginWithQuickConnect() async throws {
        guard let seerrURL, let profileID, let jellyfin else { throw SeerrAPIError.missingSession }
        let quickConnect = try await SeerrAPI.initiateQuickConnect(seerrURL: seerrURL)
        _ = try await jellyfin.send(Paths.authorizeQuickConnect(code: quickConnect.code))
        let session = try await SeerrAPI.authenticateQuickConnect(seerrURL: seerrURL, secret: quickConnect.secret)
        guard self.seerrURL == seerrURL, self.profileID == profileID else { throw CancellationError() }
        await activate(session: session, seerrURL: seerrURL, profileID: profileID)
    }

    private func activate(session: String, seerrURL: String, profileID: UUID) async {
        SeerrSessionStore.save(session, for: profileID)
        SeerrSessionStore.setAutoLoginDisabled(false, for: profileID)
        api = SeerrAPI(seerrURL: seerrURL, session: session)
        user = try? await api?.currentUser()
    }

    func logout(disableAutoLogin: Bool = false) {
        let api = api
        autoLoginTask?.cancel()
        clearSession()
        if disableAutoLogin, let profileID { SeerrSessionStore.setAutoLoginDisabled(true, for: profileID) }
        Task { await api?.logout() }
    }

    // MARK: - Calls

    func perform<T>(_ call: (SeerrAPI) async throws -> T) async throws -> T {
        guard let api else { throw SeerrAPIError.missingSession }
        do {
            return try await call(api)
        } catch SeerrAPIError.unauthorized {
            await validateSession()
            guard let renewed = self.api, renewed.session != api.session else { throw SeerrAPIError.unauthorized }
            return try await call(renewed)
        }
    }

    func items(_ call: (SeerrAPI) async throws -> [SeerrMediaItem]) async -> [SeerrMediaItem] {
        guard isLoggedIn else { return [] }
        return (try? await perform(call)) ?? []
    }

    // MARK: - Session

    private func validateSession() async {
        guard let api else { return }
        do {
            let user = try await api.currentUser()
            guard !Task.isCancelled else { return }
            self.user = user
        } catch SeerrAPIError.unauthorized {
            guard self.api?.session == api.session else { return }
            clearSession()
            await autoLogin()
        } catch {
            // Seerr unreachable: keep the session for later
        }
    }

    private func autoLogin() async {
        if let autoLoginTask { return await autoLoginTask.value }
        guard let profileID, !SeerrSessionStore.isAutoLoginDisabled(for: profileID) else { return }
        let task = Task { _ = try? await loginWithQuickConnect() }
        autoLoginTask = task
        await task.value
        if autoLoginTask == task { autoLoginTask = nil }
    }

    private func clearSession() {
        validationTask?.cancel()
        if let profileID { SeerrSessionStore.delete(for: profileID) }
        api = nil
        user = nil
    }
}
