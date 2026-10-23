//
//  SeerrLoginView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct SeerrLoginView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    private var username: String {
        appState.currentUser?.name ?? ""
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(i18n.t("login:username"), value: username)
                SecureField(i18n.t("login:password"), text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit(login)
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    Text(i18n.t("sidebar:seerr_login_description"))
                }
            }

            Section {
                Button(action: login) {
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
        .navigationTitle(i18n.t("sidebar:seerr_login_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func login() {
        guard !username.isEmpty, !isLoggingIn else { return }
        errorMessage = nil
        isLoggingIn = true
        Task {
            defer { isLoggingIn = false }
            do {
                try await seerrStore.login(username: username, password: password)
                dismiss()
            } catch {
                errorMessage = i18n.t("sidebar:seerr_login_failed")
            }
        }
    }
}
