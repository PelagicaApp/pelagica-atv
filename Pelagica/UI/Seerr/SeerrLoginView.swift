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
        PelagicaScreen {
            VStack(spacing: 16) {
                Text(i18n.t("sidebar:seerr_login_title"))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                Text(i18n.t("sidebar:seerr_login_description"))
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 900)

            VStack(alignment: .leading, spacing: 20) {
                Text(username)
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))

                PelagicaField(
                    placeholder: i18n.t("login:password"),
                    text: $password,
                    isSecure: true,
                    label: i18n.t("login:password"),
                    contentType: .password,
                    onCommit: login
                )

                Button(action: login) {
                    Text(isLoggingIn ? i18n.t("login:logging_in") : i18n.t("login:login"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .primary))
                .disabled(username.isEmpty || isLoggingIn)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .frame(maxWidth: 700)
        }
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
