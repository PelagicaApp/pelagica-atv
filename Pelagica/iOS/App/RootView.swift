//
//  RootView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.isRestoringSession {
                ProgressView()
            } else if appState.isLoggedIn {
                ContentUnavailableView(
                    appState.currentUser?.name ?? "Pelagica",
                    systemImage: "play.tv",
                    description: Text("The iOS interface is under construction.")
                )
            } else {
                ContentUnavailableView(
                    "Not signed in",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Sign-in for iOS is under construction.")
                )
            }
        }
        .environmentObject(appState)
        .preferredColorScheme(.dark)
        .task { await appState.restoreSession() }
    }
}

#Preview {
    RootView()
}
