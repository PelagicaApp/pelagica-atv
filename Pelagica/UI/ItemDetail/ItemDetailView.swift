//
//  ItemDetailView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configStore: AppConfigStore
    @Environment(\.openURL) private var openURL

    @State private var item: BaseItemDto
    @State private var nextEpisode: BaseItemDto?
    @State private var isWatchlist: Bool
    @State private var isTogglingWatchlist = false
    @State private var similarItems: [BaseItemDto] = []
    @State private var collectionItems: [String: [BaseItemDto]] = [:]

    @State private var seasons: [BaseItemDto] = []
    @State private var selectedSeasonID: String?
    @State private var episodes: [BaseItemDto] = []

    @State private var boxSetItems: [BaseItemDto] = []

    @State private var playbackTarget: PlaybackTarget?
    @State private var localTrailers: [BaseItemDto] = []

    @Namespace private var heroNamespace
    @Namespace private var seasonsNamespace
    @Namespace private var episodesNamespace
    @Namespace private var similarNamespace
    @Namespace private var boxSetNamespace
    @FocusState private var isPlayButtonFocused: Bool

    init(item: BaseItemDto) {
        _item = State(initialValue: item)
        _isWatchlist = State(initialValue: item.userData?.isLikes ?? false)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 60) {
                    heroSection
                        .frame(height: proxy.size.height * 0.87)
                        .focusScope(heroNamespace)
                        .focusSection()

                    if item.type == .series {
                        ItemDetailEpisodesSection(
                            seasons: seasons,
                            selectedSeasonID: $selectedSeasonID,
                            episodes: episodes,
                            seasonsNamespace: seasonsNamespace,
                            episodesNamespace: episodesNamespace,
                            onPlayEpisode: startPlayback,
                            onTogglePlayed: togglePlayed,
                            onSelectSeason: { await loadEpisodes(seasonID: $0) }
                        )
                    }

                    if item.type == .boxSet, !boxSetItems.isEmpty {
                        ItemDetailBoxSetSection(
                            items: boxSetItems,
                            nextItemID: nextBoxSetItem?.id,
                            namespace: boxSetNamespace
                        )
                    }

                    if localTrailers.count > 1 {
                        ItemTrailersSection(
                            trailers: localTrailers,
                            onPlayTrailer: playLocalTrailer
                        )
                    }
                    
                    if let people = item.people, !people.isEmpty {
                        ItemDetailsPeopleSection(people: people)
                    }

                    if !collectionItems.isEmpty {
                        ItemDetailCollectionsSection(collectionItems: collectionItems)
                    }

                    if !similarItems.isEmpty {
                        ItemDetailSimilarSection(items: similarItems, namespace: similarNamespace)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .background(PelagicaBackground())
        .task {
            await loadFullItem()
            await loadLocalTrailers()
            await laodSimilarItems()
            if item.type == .series {
                await loadNextEpisode()
                await loadSeasons()
            }
            if item.type == .boxSet {
                await loadBoxSetItems()
            }
            if item.type == .movie {
                if configStore.config.itemPage?.showCollections != false {
                    await loadItemCollections()
                }
            }
        }
        .fullScreenCover(item: $playbackTarget) { target in
            VideoPlayerView(item: target.item, startTicks: target.startTicks)
                .ignoresSafeArea()
        }
        .onChange(of: playbackTarget == nil) { wasNilBefore, isNilNow in
            guard isNilNow, !wasNilBefore else { return }
            Task {
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
        }
    }

    private var heroSection: some View {
        ItemDetailHeroSection(
            item: item,
            isWatchlist: isWatchlist,
            isTogglingWatchlist: isTogglingWatchlist,
            trailerAvailable: !localTrailers.isEmpty || trailerURL != nil,
            playLabel: playLabel,
            namespace: heroNamespace,
            isPlayButtonFocused: $isPlayButtonFocused,
            onPlay: play,
            onPlayTrailer: playTrailer,
            onToggleWatchlist: toggleWatchlist
        )
    }

    private var playLabel: String {
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

    // MARK: - Actions

    private func play() {
        let target: BaseItemDto? = switch item.type {
        case .series: nextEpisode
        case .boxSet: nextBoxSetItem
        default: item
        }
        guard let target else { return }
        startPlayback(for: target)
    }

    private func playTrailer() {
        if !localTrailers.isEmpty, let firstTrailer = localTrailers.first {
            startPlayback(for: firstTrailer)
        } else if let trailerURL {
            openURL(trailerURL)
        }
    }
    
    private func playLocalTrailer(trailer: BaseItemDto) {
        startPlayback(for: trailer)
    }

    private func startPlayback(for target: BaseItemDto) {
        guard target.id != nil else { return }
        let startTicks = target.userData?.playbackPositionTicks ?? 0
        playbackTarget = PlaybackTarget(item: target, startTicks: startTicks)
    }

    private func toggleWatchlist() {
        guard let client = appState.client, let id = item.id, !isTogglingWatchlist else { return }
        let newValue = !isWatchlist
        isWatchlist = newValue
        isTogglingWatchlist = true

        Task {
            defer { isTogglingWatchlist = false }
            do {
                _ = try await client.send(Paths.updateItemUserData(
                    itemID: id,
                    userID: appState.currentUser?.id,
                    UpdateUserItemDataDto(isLikes: newValue)
                ))
            } catch {
                isWatchlist = !newValue
            }
        }
    }

    private func togglePlayed(_ episode: BaseItemDto) {
        guard let client = appState.client, let id = episode.id else { return }
        let userID = appState.currentUser?.id
        let markPlayed = episode.userData?.isPlayed != true

        Task {
            do {
                let userData = try await client.send(markPlayed
                    ? Paths.markPlayedItem(itemID: id, userID: userID)
                    : Paths.markUnplayedItem(itemID: id, userID: userID)
                ).value
                if let index = episodes.firstIndex(where: { $0.id == id }) {
                    episodes[index].userData = userData
                }
                appState.notifyWatchStateChanged()
                await loadFullItem()
                await loadNextEpisode()
            } catch {
                // The episode keeps its previous state, which the menu still reflects.
            }
        }
    }

    // MARK: - Data loading

    private func loadFullItem() async {
        guard let client = appState.client, let id = item.id else { return }
        do {
            let full = try await client.send(Paths.getItem(itemID: id, userID: appState.currentUser?.id)).value
            item = full
            isWatchlist = full.userData?.isLikes ?? false
        } catch {
            // The stub data passed in from the grid is enough to render the page.
        }
    }

    private func loadLocalTrailers() async {
        guard let client = appState.client, let id = item.id, (item.localTrailerCount ?? 0) > 0 else { return }
        do {
            let trailers = try await client.send(Paths.getLocalTrailers(itemID: id, userID: appState.currentUser?.id)).value
            localTrailers = trailers
        } catch {
            // Just leave trailers empty
        }
    }

    private func loadNextEpisode() async {
        guard let client = appState.client, let seriesID = item.id else { return }
        do {
            let nextUp = try await client.send(Paths.getNextUp(parameters: .init(
                userID: appState.currentUser?.id,
                limit: 1,
                fields: [.overview],
                seriesID: seriesID
            ))).value
            if let episode = nextUp.items?.first {
                nextEpisode = episode
                return
            }

            let episodes = try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: .init(
                userID: appState.currentUser?.id,
                fields: [.overview],
                limit: 1
            ))).value
            nextEpisode = episodes.items?.first
        } catch {
            // The Play button just falls back to a generic label.
        }
    }

    private func loadSeasons() async {
        guard let client = appState.client, let seriesID = item.id else { return }
        do {
            let result = try await client.send(Paths.getSeasons(seriesID: seriesID, parameters: .init(
                userID: appState.currentUser?.id
            ))).value
            seasons = result.items ?? []
            selectedSeasonID = seasons.first(where: { $0.indexNumber == nextEpisode?.parentIndexNumber })?.id ?? seasons.first?.id
        } catch {
            // The episodes section just won't show if seasons fail to load.
        }
    }

    private func loadEpisodes(seasonID: String) async {
        guard let client = appState.client, let seriesID = item.id else { return }
        do {
            let result = try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: .init(
                userID: appState.currentUser?.id,
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
        guard let client = appState.client, let boxSetID = item.id else { return }
        let sort = configStore.config.itemPage?.collectionSort ?? .premiereDateAsc
        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: appState.currentUser?.id,
                parentID: boxSetID,
                enableUserData: true
            ))).value
            boxSetItems = CollectionSorting.sort(result.items ?? [], by: sort)
        } catch {
            // The box set row just won't show if its items fail to load.
        }
    }

    private func laodSimilarItems() async {
        guard let client = appState.client, let itemID = item.id else { return }
        do {
            let result = try await client.send(Paths.getSimilarItems(itemID: itemID)).value
            similarItems = result.items ?? []
        } catch {
            similarItems = []
        }
    }

    private func loadItemCollections() async {
        guard let client = appState.client, let itemID = item.id else { return }
        let sort = configStore.config.itemPage?.collectionSort ?? .premiereDateAsc
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

    // MARK: - Box set

    private var nextBoxSetItem: BaseItemDto? {
        let playable = CollectionSorting.sort(boxSetItems, by: .premiereDateAsc).filter { $0.isFolder != true }
        let inProgress = playable.first {
            ($0.userData?.playbackPositionTicks ?? 0) > 0 && $0.userData?.isPlayed != true
        }
        return inProgress
            ?? playable.first { $0.userData?.isPlayed != true }
            ?? playable.first
    }

    // MARK: - Trailer

    private var trailerURL: URL? {
        item.remoteTrailers?.first?.url.flatMap(URL.init(string:))
    }
}

#Preview {
    ItemDetailView(item: BaseItemDto(name: "Preview Item", overview: "A short preview overview."))
        .environmentObject(AppState())
        .environmentObject(AppConfigStore())
}
