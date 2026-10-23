//
//  ServerConnectView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ServerConnectView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var path: NavigationPath

    @StateObject private var model = ServerConnectModel()

    var body: some View {
        Form {
            Section {
                AuthHeader()
                    .listRowBackground(Color.clear)
            }

            Section {
                TextField("jellyfin.example.com", text: $model.address)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(connect)

                Button(action: connect) {
                    HStack {
                        Text(model.isConnecting ? i18n.t("login:connecting") : i18n.t("login:connect"))
                        if model.isConnecting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(!model.canConnect)
            } header: {
                Text(i18n.t("login:server_address"))
            } footer: {
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    Text(i18n.t("login:enter_manually"))
                }
            }

            if !model.discoveredServers.isEmpty {
                Section(i18n.t("login:discovered_servers")) {
                    ForEach(model.discoveredServers) { server in
                        Button {
                            path.append(AuthRoute.loginMethod(DiscoveredServer(name: server.name, url: server.url)))
                        } label: {
                            LabeledContent {
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            } label: {
                                Label {
                                    Text(server.name)
                                    Text(server.url.absoluteString)
                                } icon: {
                                    Image(systemName: "server.rack")
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            if !appState.profiles.isEmpty {
                Section {
                    Button(i18n.t("profiles:back_to_profiles")) {
                        appState.cancelAddingProfile()
                    }
                }
            }
        }
        .task { await model.discoverServers() }
    }

    private func connect() {
        guard model.canConnect else { return }
        Task {
            if let server = await model.connect(appState: appState) {
                path.append(AuthRoute.loginMethod(server))
            }
        }
    }
}
