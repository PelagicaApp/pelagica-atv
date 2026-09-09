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
                    // Quick Connect isn't implemented yet.
                } label: {
                    Text("Sign in with Quick Connect")
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .primary))
                .disabled(true)

                Button {
                    path.append(AuthRoute.login(server))
                } label: {
                    Text("Sign in with username & password")
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .primary))

                Button {
                    path.removeLast(path.count)
                } label: {
                    Text("Use a different server")
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
