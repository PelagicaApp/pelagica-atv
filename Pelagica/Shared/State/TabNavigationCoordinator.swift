//
//  TabNavigationCoordinator.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI
import SwiftUI

enum MainTab: Hashable {
    case home
    case library
    case search
    case settings
}

@MainActor
final class TabNavigationCoordinator: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var pendingLibrary: BaseItemDto?

    @Published var homePath = NavigationPath()
    @Published var libraryPath = NavigationPath()
    @Published var searchPath = NavigationPath()

    @Published var pendingSearchQuery: String?
    @Published var playbackTarget: PlaybackTarget?
    @Published var isShowingSettings = false

    func openLibrary(_ library: BaseItemDto) {
        selectedTab = .library
        pendingLibrary = library
    }

    // MARK: - Deep links

    func open(_ link: DeepLink, appState: AppState) async {
        isShowingSettings = false

        switch link {
        case .tab(let tab):
            select(tab)

        case .search(let query):
            selectedTab = .search
            searchPath = NavigationPath()
            pendingSearchQuery = query

        case .item(let id):
            push(ItemDetailRoute(item: BaseItemDto(id: id)))

        case .person(let id):
            push(PersonDetailRoute(id: id, name: nil))

        case .seerr(let type, let tmdbID):
            push(SeerrItemRoute(tmdbID: tmdbID, mediaType: type))

        case .library(let id):
            let library = await fetchItem(id, appState: appState) ?? BaseItemDto(id: id)
            selectedTab = .library
            var path = NavigationPath()
            #if os(tvOS)
            path.append(library)
            #else
            path.append(LibraryRoute(library: library))
            #endif
            libraryPath = path

        case .play(let id):
            guard let item = await fetchItem(id, appState: appState) else {
                push(ItemDetailRoute(item: BaseItemDto(id: id)))
                return
            }
            if item.isFolder == true {
                push(ItemDetailRoute(item: item))
            } else {
                playbackTarget = PlaybackTarget(item: item, startTicks: item.userData?.playbackPositionTicks ?? 0)
            }
        }
    }

    private func select(_ tab: MainTab) {
        #if os(tvOS)
        selectedTab = tab
        #else
        if tab == .settings {
            isShowingSettings = true
        } else {
            selectedTab = tab
        }
        #endif
    }

    /// Opens the route on top of the current tab's root, falling back to Home.
    private func push<Route: Hashable>(_ route: Route) {
        var path = NavigationPath()
        path.append(route)
        switch selectedTab {
        case .library:
            libraryPath = path
        case .search:
            searchPath = path
        case .home, .settings:
            selectedTab = .home
            homePath = path
        }
    }

    private func fetchItem(_ id: String, appState: AppState) async -> BaseItemDto? {
        guard let client = appState.client else { return nil }
        return try? await client.send(Paths.getItem(itemID: id, userID: appState.currentUser?.id)).value
    }
}
