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
                ZStack {
                    Color.black.ignoresSafeArea()
                    PelagicaIcon(size: 72)
                }
            } else if appState.isLoggedIn {
                HomeView()
            } else {
                AuthFlowView()
            }
        }
        .environmentObject(appState)
        .task { await appState.restoreSession() }
    }
}

#Preview {
    ContentView()
}
