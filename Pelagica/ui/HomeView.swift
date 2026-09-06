//
//  HomeView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                PelagicaIcon(size: 72)

                Text("You're logged in")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    if let name = appState.currentUser?.name {
                        Text(name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    if let serverName = appState.serverName {
                        Text(serverName)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    appState.signOut()
                } label: {
                    Text("Sign Out")
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
                .frame(maxWidth: 300)
                .padding(.top, 24)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
