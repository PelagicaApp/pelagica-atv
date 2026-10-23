//
//  LoginMethodView.swift
//  Pelagica
//

import SwiftUI

struct LoginMethodView: View {
    let server: DiscoveredServer
    @Binding var path: NavigationPath

    var body: some View {
        PelagicaScreen {
            PelagicaHeader()

            VStack(spacing: 20) {
                Button {
                    path.append(AuthRoute.quickConnect(server))
                } label: {
                    Text(i18n.t("login:sign_in_with_quick_connect"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .primary))
                
                Button {
                    path.append(AuthRoute.login(server))
                } label: {
                    Text(i18n.t("login:sign_in_with_password"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
                
                Button {
                    path.removeLast(path.count)
                } label: {
                    Text(i18n.t("login:use_different_server"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .plain))
            }
            .frame(maxWidth: 700)
        }
    }
}

#Preview {
    LoginMethodView(
        server: DiscoveredServer(name: "JanNAS", url: URL(string: "http://192.168.178.131:8096")!),
        path: .constant(NavigationPath())
    )
}
