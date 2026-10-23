//
//  QuickConnectModel.swift
//  Pelagica
//

import Combine
import Foundation

@MainActor
final class QuickConnectModel: ObservableObject {
    let server: DiscoveredServer

    @Published private(set) var code: String?
    @Published private(set) var errorMessage: String?

    private var pollingTask: Task<Void, Never>?

    init(server: DiscoveredServer) {
        self.server = server
    }

    /// Requests a code, then polls until the user approves it, which signs in through `appState`.
    func start(appState: AppState) async {
        do {
            let result = try await appState.initiateQuickConnect(server: server)
            guard let result else {
                errorMessage = i18n.t("login:quick_connect_failed")
                return
            }
            code = result.code
            startPolling(secret: result.secret, appState: appState)
        } catch {
            errorMessage = i18n.t("login:quick_connect_failed")
        }
    }

    func stop() {
        pollingTask?.cancel()
    }

    /// Link to the server's web Quick Connect page with the code filled in, for a QR code.
    var quickConnectURL: URL? {
        guard let code, !code.isEmpty else { return nil }

        guard var components = URLComponents(url: server.url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = "/web/"
        components.fragment = "/quickconnect?code=\(code)"

        return components.url
    }

    private func startPolling(secret: String, appState: AppState) {
        pollingTask?.cancel()
        let server = server
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }

                do {
                    let isAuthenticated = try await appState.checkQuickConnectStatus(server: server, secret: secret)
                    if isAuthenticated {
                        try await appState.authenticateQuickConnect(server: server, secret: secret)
                        return
                    }
                } catch {
                    errorMessage = i18n.t("login:quick_connect_failed")
                    return
                }
            }
        }
    }
}
