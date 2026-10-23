//
//  MainTabView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var configStore = AppConfigStore()
    @StateObject private var seerrStore = SeerrStore()
    @StateObject private var playerPresenter = PlayerPresenter()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Translations.languageDefaultsKey) private var languageOverride: String?

    var body: some View {
        Group {
            if configStore.isLoading || !seerrStore.isReady {
                ProgressView()
            } else {
                TabView {
                    Tab(i18n.t("home:title"), systemImage: "house.fill") {
                        HomeView()
                    }
                    Tab(i18n.t("library:title"), systemImage: "books.vertical.fill") {
                        LibrariesView()
                    }
                    Tab(i18n.t("settings:title"), systemImage: "gearshape.fill") {
                        SettingsView()
                    }
                    Tab(i18n.t("search"), systemImage: "magnifyingglass", role: .search) {
                        SearchView()
                    }
                }
                .id(languageOverride)
                .playerCover($playerPresenter.target)
            }
        }
        .environmentObject(configStore)
        .environmentObject(seerrStore)
        .environmentObject(playerPresenter)
        .task { await reload() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await reload() }
        }
    }

    private func reload() async {
        guard let client = appState.client else { return }
        await configStore.load(client: client)
        await seerrStore.configure(
            seerrURL: configStore.config.seerrURL,
            profileID: appState.activeProfile?.id,
            pendingLogin: appState.pendingSeerrLogin
        )
    }
}
