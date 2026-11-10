//
//  MediaBarModel.swift
//  Pelagica
//

import Combine
import Foundation
import JellyfinAPI

@MainActor
final class MediaBarModel: ObservableObject {
    @Published private(set) var nextEpisode: BaseItemDto?
    @Published private(set) var isFavorite = false
    @Published private(set) var isWatchlist = false
    @Published private(set) var isTogglingFavorite = false
    @Published private(set) var isTogglingWatchlist = false

    private var item: BaseItemDto?
    private var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
    }

    func show(_ item: BaseItemDto?) async {
        self.item = item
        isFavorite = item?.userData?.isFavorite ?? false
        isWatchlist = item?.userData?.isLikes ?? false
        await loadNextEpisode()
    }

    func toggleFavorite() {
        guard let client = appState?.client, let id = item?.id, !isTogglingFavorite else { return }
        let newValue = !isFavorite
        isFavorite = newValue
        isTogglingFavorite = true

        Task {
            defer { isTogglingFavorite = false }
            do {
                try await ItemActions.setFavorite(newValue, itemID: id, client: client, userID: appState?.currentUser?.id)
            } catch {
                isFavorite = !newValue
            }
        }
    }

    func toggleWatchlist() {
        guard let client = appState?.client, let id = item?.id, !isTogglingWatchlist else { return }
        let newValue = !isWatchlist
        isWatchlist = newValue
        isTogglingWatchlist = true

        Task {
            defer { isTogglingWatchlist = false }
            do {
                try await ItemActions.setWatchlist(newValue, itemID: id, client: client, userID: appState?.currentUser?.id)
            } catch {
                isWatchlist = !newValue
            }
        }
    }

    private func loadNextEpisode() async {
        nextEpisode = nil
        guard let client = appState?.client, item?.type == .series, let seriesID = item?.id else { return }
        do {
            nextEpisode = try await ItemActions.nextEpisode(seriesID: seriesID, client: client, userID: appState?.currentUser?.id)
        } catch {
            // The Play button just falls back to a generic label.
        }
    }
}
