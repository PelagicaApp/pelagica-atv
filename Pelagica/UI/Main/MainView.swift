//
//  MainView.swift
//  Pelagica
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var configStore = AppConfigStore()
    @StateObject private var navigationCoordinator = TabNavigationCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if configStore.isLoading {
                PageLoadingView(text: "Loading...")
            } else {
                TabView(selection: $navigationCoordinator.selectedTab) {
                    HomeTabView()
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(MainTab.home)

                    LibraryView()
                        .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                        .tag(MainTab.library)

                    SearchTabView()
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }
                        .tag(MainTab.search)

                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                        .tag(MainTab.settings)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environmentObject(configStore)
        .environmentObject(navigationCoordinator)
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
