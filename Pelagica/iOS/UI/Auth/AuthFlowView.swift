//
//  AuthFlowView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct AuthFlowView: View {
    @State private var path: NavigationPath

    init(initialServer: DiscoveredServer? = nil) {
        var initialPath = NavigationPath()
        if let initialServer {
            initialPath.append(AuthRoute.loginMethod(initialServer))
        }
        _path = State(initialValue: initialPath)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ServerConnectView(path: $path)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .loginMethod(let server):
                        LoginMethodView(server: server, path: $path)
                    case .login(let server):
                        LoginView(server: server)
                    case .quickConnect(let server):
                        QuickConnectView(server: server)
                    }
                }
        }
    }
}

/// App logo and name at the top of the sign-in screens.
struct AuthHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image("pelagicaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
            Text("Pelagica")
                .font(.largeTitle.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
