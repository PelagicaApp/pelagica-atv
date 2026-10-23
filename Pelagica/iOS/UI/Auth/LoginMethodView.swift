//
//  LoginMethodView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct LoginMethodView: View {
    let server: DiscoveredServer
    @Binding var path: NavigationPath

    var body: some View {
        Form {
            Section {
                AuthHeader()
                    .listRowBackground(Color.clear)
            } footer: {
                Text("\(server.name) ⋅ \(server.url.absoluteString)")
                    .frame(maxWidth: .infinity)
            }

            Section {
                NavigationLink(value: AuthRoute.login(server)) {
                    Label(i18n.t("login:sign_in_with_password"), systemImage: "key")
                }
                NavigationLink(value: AuthRoute.quickConnect(server)) {
                    Label(i18n.t("login:sign_in_with_quick_connect"), systemImage: "qrcode")
                }
            }

            Section {
                Button(i18n.t("login:use_different_server")) {
                    path.removeLast(path.count)
                }
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
