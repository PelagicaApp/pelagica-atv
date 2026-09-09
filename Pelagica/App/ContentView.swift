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
                PageLoadingView(text: "Restoring session...")
            } else if appState.isLoggedIn {
                MainView()
            } else {
                AuthFlowView()
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
