//
//  MainView.swift
//  Pelagica
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var configStore = AppConfigStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if configStore.isLoading {
                PageLoadingView(text: "Loading...")
            } else {
                TabView {
                    HomeTabView()
                        .tabItem { Label("Home", systemImage: "house.fill") }

                    LibraryView()
                        .tabItem { Label("Library", systemImage: "books.vertical.fill") }

                    SearchTabView()
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }

                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environmentObject(configStore)
        .task {
            guard let client = appState.client else { return }
            await configStore.load(client: client)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let client = appState.client else { return }
            Task { await configStore.load(client: client) }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
