//
//  RootView.swift
//  Pelagica
//

import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.isRestoringSession {
                ProgressView()
            } else if appState.isLoggedIn {
                MainTabView()
            } else if appState.showsProfilePicker {
                ProfileSelectView()
            } else {
                AuthFlowView(initialServer: appState.reauthServer)
            }
        }
        .environmentObject(appState)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task { await appState.restoreSession() }
    }
}

#Preview {
    RootView()
}
