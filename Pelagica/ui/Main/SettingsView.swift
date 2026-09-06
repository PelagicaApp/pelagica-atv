//
//  SettingsView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 40) {
                Text("Settings")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 0) {
                    SettingsRow(label: "Signed in as", value: appState.currentUser?.name ?? "Unknown")
                    Divider().overlay(Color.white.opacity(0.1))
                    SettingsRow(label: "Server", value: appState.serverName ?? "Unknown")
                    Divider().overlay(Color.white.opacity(0.1))
                    SettingsRow(label: "Address", value: appState.client?.configuration.url.absoluteString ?? "Unknown")
                }
                .padding(.horizontal, 28)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: 900, alignment: .leading)

                Button {
                    appState.signOut()
                } label: {
                    Text("Sign Out")
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
                .frame(maxWidth: 300)

                Spacer()
            }
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .font(.system(size: 24))
        .padding(.vertical, 20)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
