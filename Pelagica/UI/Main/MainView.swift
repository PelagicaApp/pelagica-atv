//
//  MainView.swift
//  Pelagica
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var configStore = AppConfigStore()
    @StateObject private var seerrStore = SeerrStore()
    @StateObject private var navigationCoordinator = TabNavigationCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Translations.languageDefaultsKey) private var languageOverride: String?

    var body: some View {
        Group {
            if configStore.isLoading || !seerrStore.isReady {
                PageLoadingView(text: i18n.t("loading"))
            } else {
                TabView(selection: $navigationCoordinator.selectedTab) {
                    HomeTabView()
                        .tabItem { Label(i18n.t("home:title"), systemImage: "house.fill") }
                        .tag(MainTab.home)

                    LibraryView()
                        .tabItem { Label(i18n.t("library:title"), systemImage: "books.vertical.fill") }
                        .tag(MainTab.library)

                    SearchTabView()
                        .tabItem { Label(i18n.t("search"), systemImage: "magnifyingglass") }
                        .tag(MainTab.search)

                    SettingsView()
                        .tabItem { Label(i18n.t("settings:title"), systemImage: "gearshape.fill") }
                        .tag(MainTab.settings)
                }
                .id(languageOverride)
            }
        }
        .background(PelagicaBackground())
        .environmentObject(configStore)
        .environmentObject(seerrStore)
        .environmentObject(navigationCoordinator)
        .task {
            guard let client = appState.client else { return }
            await configStore.load(client: client)
            await configureSeerr()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let client = appState.client else { return }
            Task {
                await configStore.load(client: client)
                await configureSeerr()
            }
        }
    }

    private func configureSeerr() async {
        await seerrStore.configure(
            seerrURL: configStore.config.seerrURL,
            profileID: appState.activeProfile?.id,
            pendingLogin: appState.pendingSeerrLogin
        )
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
