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
                PelagicaField(placeholder: "Username", text: $username, label: "Username", contentType: .username)
                PelagicaField(placeholder: "Password", text: $password, isSecure: true, label: "Password", contentType: .password, onCommit: signIn)

                Button {
                    signIn()
                } label: {
                    Text(isLoggingIn ? "Signing in…" : "Login")
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
                    Text("Back")
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
                errorMessage = "Incorrect username or password."
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
