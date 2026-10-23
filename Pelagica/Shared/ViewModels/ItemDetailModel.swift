//
//  ItemDetailModel.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI

@MainActor
final class ItemDetailModel: ObservableObject {
    @Published private(set) var item: BaseItemDto
    @Published private(set) var nextEpisode: BaseItemDto?
    @Published private(set) var isWatchlist: Bool
    @Published private(set) var isTogglingWatchlist = false
    @Published private(set) var isFavorite: Bool
    @Published private(set) var isTogglingFavorite = false
    @Published private(set) var isTogglingPlayed = false
    @Published private(set) var similarItems: [BaseItemDto] = []
    @Published private(set) var collectionItems: [String: [BaseItemDto]] = [:]
    @Published private(set) var seerrRecommendations: [SeerrMediaItem] = []

    @Published private(set) var seasons: [BaseItemDto] = []
    @Published var selectedSeasonID: String?
    @Published private(set) var episodes: [BaseItemDto] = []

    @Published private(set) var boxSetItems: [BaseItemDto] = []

    @Published var playbackTarget: PlaybackTarget?
    @Published private(set) var localTrailers: [BaseItemDto] = []

    private let themeSong = ThemeSongPlayer()

    private var appState: AppState?
    private var configStore: AppConfigStore?
    private var seerrStore: SeerrStore?

    init(item: BaseItemDto) {
        self.item = item
        isWatchlist = item.userData?.isLikes ?? false
        isFavorite = item.userData?.isFavorite ?? false
    }

    func bind(appState: AppState, configStore: AppConfigStore, seerrStore: SeerrStore) {
        self.appState = appState
        self.configStore = configStore
        self.seerrStore = seerrStore
    }

    private var client: JellyfinClient? { appState?.client }
    private var userID: String? { appState?.currentUser?.id }

    // MARK: - Lifecycle

    func load() async {
        await loadFullItem()
        if let appState {
            await themeSong.play(for: item, appState: appState)
        }
        await loadLocalTrailers()
        await loadSimilarItems()
        await loadSeerrRecommendations()
        if item.type == .series {
            await loadNextEpisode()
            await loadSeasons()
        }
        if item.type == .boxSet {
            await loadBoxSetItems()
        }
        if item.type == .movie {
            if configStore?.config.itemPage?.showCollections != false {
                await loadItemCollections()
            }
        }
    }

    /// Refreshes progress after the player closes.
    func playbackEnded() async {
        await loadFullItem()
        if item.type == .series {
            await loadNextEpisode()
            if let selectedSeasonID {
                await loadEpisodes(seasonID: selectedSeasonID)
            }
        }
        if item.type == .boxSet {
            await loadBoxSetItems()
        }
    }

    func stopThemeSong() {
        themeSong.stop()
    }

    // MARK: - Derived state

    var seerrRoute: SeerrItemRoute? {
        guard seerrStore?.isLoggedIn == true, let mediaType = seerrMediaType,
              let tmdbID = item.providerIDs?["Tmdb"].flatMap(Int.init) else { return nil }
        return SeerrItemRoute(tmdbID: tmdbID, mediaType: mediaType, title: item.name)
    }

    private var seerrMediaType: SeerrMediaType? {
        switch item.type {
        case .movie: .movie
        case .series: .tv
        default: nil
        }
    }

    var playLabel: String {
        if item.type == .series {
            guard let nextEpisode else { return i18n.t("item:play") }
            let season = nextEpisode.parentIndexNumber ?? 1
            let episode = nextEpisode.indexNumber ?? 1
            return i18n.t("item:play_episode", ["season": season, "episode": episode])
        }

        let playable = item.type == .boxSet ? nextBoxSetItem : item
        guard let playable else { return i18n.t("item:play") }
        let hasProgress = (playable.userData?.playbackPositionTicks ?? 0) > 0 && playable.userData?.isPlayed != true
        return hasProgress ? i18n.t("resume") : i18n.t("item:play")
    }

    var isPlayed: Bool {
        item.userData?.isPlayed ?? false
    }

    private var isMovieOrSeries: Bool {
        item.type == .movie || item.type == .series
    }

    var showsWatchlistButton: Bool {
        isMovieOrSeries && configStore?.config.itemPage?.showWatchlistButton == true
    }

    var showsFavoriteButton: Bool {
        guard isMovieOrSeries || item.type == .boxSet else { return false }
        guard let allowedTypes = configStore?.config.itemPage?.favoriteButton, let type = item.type else { return true }
        return allowedTypes.contains(type.rawValue)
    }

    var showsPlayedButton: Bool {
        isMovieOrSeries
    }

    var detailBadges: [DetailBadgeValue] {
        let types = configStore?.config.itemPage?.detailBadges ?? DetailBadges.defaultBadges
        return types.compactMap { DetailBadges.value(for: item, type: $0) }
    }

    var trailerAvailable: Bool {
        !localTrailers.isEmpty || trailerURL != nil
    }

    var nextBoxSetItem: BaseItemDto? {
        let playable = CollectionSorting.sort(boxSetItems, by: .premiereDateAsc).filter { $0.isFolder != true }
        let inProgress = playable.first {
            ($0.userData?.playbackPositionTicks ?? 0) > 0 && $0.userData?.isPlayed != true
        }
        return inProgress
            ?? playable.first { $0.userData?.isPlayed != true }
            ?? playable.first
    }

    private var trailerURL: URL? {
        item.remoteTrailers?.first?.url.flatMap(URL.init(string:))
    }

    // MARK: - Actions

    func play() {
        let target: BaseItemDto? = switch item.type {
        case .series: nextEpisode
        case .boxSet: nextBoxSetItem
        default: item
        }
        guard let target else { return }
        startPlayback(for: target)
    }

    /// Plays a local trailer, or returns the remote trailer's URL for the view to open.
    func playTrailer() -> URL? {
        if let firstTrailer = localTrailers.first {
            startPlayback(for: firstTrailer)
            return nil
        }
        guard let trailerURL else { return nil }
        themeSong.stop()
        return trailerURL
    }

    func startPlayback(for target: BaseItemDto) {
        guard target.id != nil else { return }
        themeSong.stop(fade: false)
        let startTicks = target.userData?.playbackPositionTicks ?? 0
        playbackTarget = PlaybackTarget(item: target, startTicks: startTicks)
    }

    func toggleWatchlist() {
        guard let client, let id = item.id, !isTogglingWatchlist else { return }
        let newValue = !isWatchlist
        isWatchlist = newValue
        isTogglingWatchlist = true

        Task {
            defer { isTogglingWatchlist = false }
            do {
                try await ItemActions.setWatchlist(newValue, itemID: id, client: client, userID: userID)
            } catch {
                isWatchlist = !newValue
            }
        }
    }

    func toggleFavorite() {
        guard let client, let id = item.id, !isTogglingFavorite else { return }
        let newValue = !isFavorite
        isFavorite = newValue
        isTogglingFavorite = true

        Task {
            defer { isTogglingFavorite = false }
            do {
                try await ItemActions.setFavorite(newValue, itemID: id, client: client, userID: userID)
            } catch {
                isFavorite = !newValue
            }
        }
    }

    func toggleItemPlayed() {
        guard let client, let id = item.id, !isTogglingPlayed else { return }
        let markPlayed = item.userData?.isPlayed != true
        isTogglingPlayed = true

        Task {
            defer { isTogglingPlayed = false }
            do {
                item.userData = try await ItemActions.setPlayed(markPlayed, itemID: id, client: client, userID: userID)
                appState?.notifyWatchStateChanged()
                if item.type == .series {
                    if let selectedSeasonID {
                        await loadEpisodes(seasonID: selectedSeasonID)
                    }
                    await loadNextEpisode()
                }
            } catch {
                // The button keeps the previous state.
            }
        }
    }

    func togglePlayed(_ episode: BaseItemDto) {
        guard let client, let id = episode.id else { return }
        let markPlayed = episode.userData?.isPlayed != true

        Task {
            do {
                let userData = try await ItemActions.setPlayed(markPlayed, itemID: id, client: client, userID: userID)
                if let index = episodes.firstIndex(where: { $0.id == id }) {
                    episodes[index].userData = userData
                }
                appState?.notifyWatchStateChanged()
                await loadFullItem()
                await loadNextEpisode()
            } catch {
                // The episode keeps its previous state, which the menu still reflects.
            }
        }
    }

    // MARK: - Data loading

    private func loadFullItem() async {
        guard let client, let id = item.id else { return }
        do {
            let full = try await client.send(Paths.getItem(itemID: id, userID: userID)).value
            item = full
            isWatchlist = full.userData?.isLikes ?? false
            isFavorite = full.userData?.isFavorite ?? false
        } catch {
            // The stub data passed in from the grid is enough to render the page.
        }
    }

    private func loadLocalTrailers() async {
        guard let client, let id = item.id, (item.localTrailerCount ?? 0) > 0 else { return }
        do {
            let trailers = try await client.send(Paths.getLocalTrailers(itemID: id, userID: userID)).value
            localTrailers = trailers
        } catch {
            // Just leave trailers empty
        }
    }

    private func loadNextEpisode() async {
        guard let client, let seriesID = item.id else { return }
        do {
            nextEpisode = try await ItemActions.nextEpisode(seriesID: seriesID, fields: [.overview], client: client, userID: userID)
        } catch {
            // The Play button just falls back to a generic label.
        }
    }

    private func loadSeasons() async {
        guard let client, let seriesID = item.id else { return }
        do {
            let result = try await client.send(Paths.getSeasons(seriesID: seriesID, parameters: .init(
                userID: userID
            ))).value
            seasons = result.items ?? []
            selectedSeasonID = seasons.first(where: { $0.indexNumber == nextEpisode?.parentIndexNumber })?.id ?? seasons.first?.id
        } catch {
            // The episodes section just won't show if seasons fail to load.
        }
    }

    func loadEpisodes(seasonID: String) async {
        guard let client, let seriesID = item.id else { return }
        do {
            let result = try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: .init(
                userID: userID,
                fields: [.overview],
                seasonID: seasonID,
                enableUserData: true,
            ))).value
            episodes = result.items ?? []
        } catch {
            episodes = []
        }
    }

    private func loadBoxSetItems() async {
        guard let client, let boxSetID = item.id else { return }
        let sort = configStore?.config.itemPage?.collectionSort ?? .premiereDateAsc
        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: userID,
                parentID: boxSetID,
                enableUserData: true
            ))).value
            boxSetItems = CollectionSorting.sort(result.items ?? [], by: sort)
        } catch {
            // The box set row just won't show if its items fail to load.
        }
    }

    private func loadSimilarItems() async {
        guard let client, let itemID = item.id else { return }
        do {
            let result = try await client.send(Paths.getSimilarItems(itemID: itemID)).value
            similarItems = result.items ?? []
        } catch {
            similarItems = []
        }
    }

    private func loadSeerrRecommendations() async {
        guard let route = seerrRoute, let seerrStore else { return }
        seerrRecommendations = await seerrStore.items {
            try await $0.recommendations(mediaType: route.mediaType, tmdbID: route.tmdbID)
        }
    }

    private func loadItemCollections() async {
        guard let client, let itemID = item.id else { return }
        let sort = configStore?.config.itemPage?.collectionSort ?? .premiereDateAsc
        do {
            let result = try await client.send(Paths.getItemCollections(itemID: itemID)).value
            guard let colls = result.items else { return }
            for coll in colls {
                guard let collName = coll.name else { continue }
                let result = try await client.send(Paths.getItems(parameters: .init(locationTypes: [LocationType.fileSystem], parentID: coll.id))).value
                guard let items = result.items else { continue }
                if items.isEmpty { continue }
                collectionItems[collName] = CollectionSorting.sort(items, by: sort)
            }
        } catch {

        }
    }
}
