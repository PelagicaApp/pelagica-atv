//
//  LoginView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    let server: DiscoveredServer

    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    private enum Field { case username, password }
    @FocusState private var focusedField: Field?

    var body: some View {
        Form {
            Section {
                TextField(i18n.t("login:username"), text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField(i18n.t("login:password"), text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(signIn)
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button(action: signIn) {
                    HStack {
                        Text(isLoggingIn ? i18n.t("login:logging_in") : i18n.t("login:login"))
                        if isLoggingIn {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(username.isEmpty || isLoggingIn)
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = .username }
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
