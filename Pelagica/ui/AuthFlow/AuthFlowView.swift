//
//  AuthFlowView.swift
//  Pelagica
//

import SwiftUI

struct AuthFlowView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ServerConnectView(path: $path)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .loginMethod(let server):
                        LoginMethodView(server: server, path: $path)
                    case .login(let server):
                        LoginView(server: server, path: $path)
                    }
                }
        }
    }
}

#Preview {
    AuthFlowView()
        .environmentObject(AppState())
}
