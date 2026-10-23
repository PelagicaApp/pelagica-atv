//
//  LoginView.swift
//  Pelagica
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    let server: DiscoveredServer
    @Binding var path: NavigationPath

    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    var body: some View {
        PelagicaScreen {
            PelagicaHeader()

            VStack(alignment: .leading, spacing: 20) {
                PelagicaField(placeholder: i18n.t("login:username"), text: $username, label: i18n.t("login:username"), contentType: .username)
                PelagicaField(placeholder: i18n.t("login:password"), text: $password, isSecure: true, label: i18n.t("login:password"), contentType: .password, onCommit: signIn)

                Button {
                    signIn()
                } label: {
                    Text(isLoggingIn ? i18n.t("login:logging_in") : i18n.t("login:login"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .primary))
                .disabled(username.isEmpty || isLoggingIn)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                Button {
                    path.removeLast()
                } label: {
                    Text(i18n.t("back"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .plain))
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 700)
        }
    }

    private func signIn() {
        guard !username.isEmpty, !isLoggingIn else { return }
        errorMessage = nil
        isLoggingIn = true
        Task {
            defer { isLoggingIn = false }
            do {
                try await appState.signIn(server: server, username: username, password: password)
            } catch {
                errorMessage = i18n.t("login:invalid_credentials")
            }
        }
    }
}

#Preview {
    LoginView(
        server: DiscoveredServer(name: "JanNAS", url: URL(string: "http://192.168.178.131:8096")!),
        path: .constant(NavigationPath())
    )
    .environmentObject(AppState())
}
