//
//  HomeTabView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                PelagicaIcon(size: 72)

                Text("Welcome back")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                if let name = appState.currentUser?.name {
                    Text(name)
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    HomeTabView()
        .environmentObject(AppState())
}
