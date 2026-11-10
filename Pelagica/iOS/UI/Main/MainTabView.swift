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
    @StateObject private var subtitleStyleStore = SubtitleStyleStore()
    @StateObject private var playerPresenter = PlayerPresenter()
    @StateObject private var navigationCoordinator = TabNavigationCoordinator()
    @State private var isShowingQuickConnect = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Translations.languageDefaultsKey) private var languageOverride: String?

    var body: some View {
        Group {
            if configStore.isLoading || !seerrStore.isReady {
                ProgressView()
            } else {
                TabView(selection: $navigationCoordinator.selectedTab) {
                    Tab(i18n.t("home:title"), systemImage: "house.fill", value: MainTab.home) {
                        HomeView()
                    }
                    Tab(i18n.t("library:title"), systemImage: "books.vertical.fill", value: MainTab.library) {
                        LibrariesView()
                    }
                    Tab(i18n.t("search"), systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                        SearchView()
                    }
                }
                .id(languageOverride)
                .environment(\.showSettings, ShowSettingsAction { navigationCoordinator.isShowingSettings = true })
                .environment(\.showQuickConnect, ShowSettingsAction { isShowingQuickConnect = true })
                .sheet(isPresented: $navigationCoordinator.isShowingSettings) {
                    SettingsView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $isShowingQuickConnect) {
                    NavigationStack {
                        QuickConnectAuthorizeView()
                    }
                    .presentationDragIndicator(.visible)
                }
                .playerCover($playerPresenter.target)
                .onChange(of: appState.pendingDeepLink, initial: true) { _, link in
                    guard let link else { return }
                    appState.pendingDeepLink = nil
                    isShowingQuickConnect = false
                    Task {
                        await navigationCoordinator.open(link, appState: appState)
                        if let target = navigationCoordinator.playbackTarget {
                            navigationCoordinator.playbackTarget = nil
                            playerPresenter.target = target
                        }
                    }
                }
            }
        }
        .environmentObject(configStore)
        .environmentObject(seerrStore)
        .environmentObject(playerPresenter)
        .environmentObject(navigationCoordinator)
        .environmentObject(subtitleStyleStore)
        .task { await reload() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await reload() }
        }
    }

    private func reload() async {
        guard let client = appState.client else { return }
        Task { await subtitleStyleStore.load(client: client, userID: appState.currentUser?.id) }
        await configStore.load(client: client)
        await seerrStore.configure(
            seerrURL: configStore.config.seerrURL,
            profileID: appState.activeProfile?.id,
            jellyfin: client,
            pendingLogin: appState.pendingSeerrLogin
        )
    }
}
