//
//  ServerConnectView.swift
//  Pelagica
//

import SwiftUI
import JellyfinAPI

struct ServerConnectView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var path: NavigationPath

    @StateObject private var model = ServerConnectModel()

    var body: some View {
        PelagicaScreen {
            PelagicaHeader()

            VStack(alignment: .leading, spacing: 16) {
                Text(i18n.t("login:enter_manually"))
                    .foregroundStyle(.secondary)

                PelagicaField(placeholder: "jellyfin.example.com", text: $model.address, label: i18n.t("login:server_address"), contentType: .URL, onCommit: connectManually)

                Button {
                    connectManually()
                } label: {
                    Text(model.isConnecting ? i18n.t("login:connecting") : i18n.t("login:connect"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .primary))
                .disabled(!model.canConnect)

                if let errorMessage = model.errorMessage {
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

            if !model.discoveredServers.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text(i18n.t("login:discovered_servers"))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        ForEach(model.discoveredServers) { server in
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
        .task { await model.discoverServers() }
    }

    private func connectManually() {
        guard model.canConnect else { return }
        Task {
            if let server = await model.connect(appState: appState) {
                path.append(AuthRoute.loginMethod(server))
            }
        }
    }
}

#Preview {
    ServerConnectView(path: .constant(NavigationPath()))
        .environmentObject(AppState())
}
