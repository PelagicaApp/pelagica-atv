//
//  ContentView.swift
//  Pelagica
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.isRestoringSession {
                PageLoadingView(text: i18n.t("loading"))
            } else if appState.isLoggedIn {
                MainView()
            } else if appState.showsProfilePicker {
                ProfileSelectView()
            } else {
                AuthFlowView(initialServer: appState.reauthServer)
            }
        }
        .environmentObject(appState)
        .preferredColorScheme(.dark)
        .task { await appState.restoreSession() }
    }
}

#Preview {
    ContentView()
}
