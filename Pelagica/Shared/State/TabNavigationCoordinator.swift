//
//  TabNavigationCoordinator.swift
//  Pelagica
//

import Combine
import Foundation
import JellyfinAPI

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

    func openLibrary(_ library: BaseItemDto) {
        selectedTab = .library
        pendingLibrary = library
    }
}
