//
//  SeerrStore.swift
//  Pelagica
//

import Combine
import Foundation

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
    }
}

@MainActor
final class SeerrStore: ObservableObject {
    @Published private(set) var api: SeerrAPI?
    @Published private(set) var user: SeerrUser?
    @Published private(set) var isReady = false

    private(set) var seerrURL: String?
    private var profileID: UUID?
    private var validationTask: Task<Void, Never>?

    var isConfigured: Bool { seerrURL != nil }
    var isLoggedIn: Bool { api != nil }

    func configure(seerrURL rawURL: String?, profileID: UUID?, pendingLogin: Task<Void, Never>?) async {
        let seerrURL = rawURL.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        defer { isReady = true }
        guard isReady == false || seerrURL != self.seerrURL || profileID != self.profileID else { return }

        await pendingLogin?.value

        self.seerrURL = seerrURL
        self.profileID = profileID
        validationTask?.cancel()
        user = nil

        guard let seerrURL, let profileID, let session = SeerrSessionStore.session(for: profileID) else {
            api = nil
            return
        }
        api = SeerrAPI(seerrURL: seerrURL, session: session)
        validationTask = Task { await validateSession() }
    }

    func login(username: String, password: String) async throws {
        guard let seerrURL, let profileID else { throw SeerrAPIError.invalidURL }
        let session = try await SeerrAPI.login(seerrURL: seerrURL, username: username, password: password)
        SeerrSessionStore.save(session, for: profileID)
        api = SeerrAPI(seerrURL: seerrURL, session: session)
        user = try? await api?.currentUser()
    }

    func logout() {
        let api = api
        clearSession()
        Task { await api?.logout() }
    }

    // MARK: - Calls

    func perform<T>(_ call: (SeerrAPI) async throws -> T) async throws -> T {
        guard let api else { throw SeerrAPIError.missingSession }
        do {
            return try await call(api)
        } catch SeerrAPIError.unauthorized {
            await validateSession()
            throw SeerrAPIError.unauthorized
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
        } catch {
            // Seerr unreachable: keep the session for later
        }
    }

    private func clearSession() {
        validationTask?.cancel()
        if let profileID { SeerrSessionStore.delete(for: profileID) }
        api = nil
        user = nil
    }
}
