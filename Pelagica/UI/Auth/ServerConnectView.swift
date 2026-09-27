//
//  ServerConnectView.swift
//  Pelagica
//

import SwiftUI
import JellyfinAPI

struct ServerConnectView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var path: NavigationPath

    @State private var address = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var discoveredServers: [JellyfinClient.PublicServer] = []

    var body: some View {
        PelagicaScreen {
            PelagicaHeader()

            VStack(alignment: .leading, spacing: 16) {
                Text(i18n.t("login:enter_manually"))
                    .foregroundStyle(.secondary)

                PelagicaField(placeholder: "jellyfin.example.com", text: $address, label: i18n.t("login:server_address"), contentType: .URL, onCommit: connectManually)

                Button {
                    connectManually()
                } label: {
                    Text(isConnecting ? i18n.t("login:connecting") : i18n.t("login:connect"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .primary))
                .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                if !appState.profiles.isEmpty {
                    Button {
                        appState.cancelAddingProfile()
                    } label: {
                        Text(i18n.t("profiles:back_to_profiles"))
                    }
                    .buttonStyle(PelagicaButtonStyle(emphasis: .plain))
                }
            }
            .frame(maxWidth: 700)

            if !discoveredServers.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text(i18n.t("login:discovered_servers"))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        ForEach(discoveredServers) { server in
                            Button {
                                path.append(AuthRoute.loginMethod(DiscoveredServer(name: server.name, url: server.url)))
                            } label: {
                                HStack {
                                    Image(systemName: "server.rack")
                                    Text(server.name).bold()
                                    Spacer()
                                    Text(server.url.absoluteString)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
                        }
                    }
                }
                .frame(maxWidth: 700)
            }
        }
        .task { await discoverServers() }
    }

    private func discoverServers() async {
        do {
            for try await server in JellyfinClient.discover() {
                if !discoveredServers.contains(server) {
                    discoveredServers.append(server)
                }
            }
        } catch {
        }
    }

    private func connectManually() {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty, !isConnecting else { return }
        errorMessage = nil
        isConnecting = true
        Task {
            defer { isConnecting = false }
            do {
                let server = try await appState.resolveServer(fromInput: address)
                path.append(AuthRoute.loginMethod(server))
            } catch {
                errorMessage = i18n.t("login:could_not_find_server")
            }
        }
    }
}

#Preview {
    ServerConnectView(path: .constant(NavigationPath()))
        .environmentObject(AppState())
}
