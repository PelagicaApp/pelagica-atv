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

    @State private var playbackTarget: PlaybackTarget?
    @State private var localTrailer: BaseItemDto?

    @Namespace private var heroNamespace
    @Namespace private var seasonsNamespace
    @Namespace private var episodesNamespace
    @Namespace private var similarNamespace
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
                            onSelectSeason: { await loadEpisodes(seasonID: $0) }
                        )
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
        .background(Color.black.ignoresSafeArea())
        .task {
            await loadFullItem()
            await loadLocalTrailer()
            await laodSimilarItems()
            if item.type == .series {
                await loadNextEpisode()
                await loadSeasons()
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
            }
        }
    }

    private var heroSection: some View {
        ItemDetailHeroSection(
            item: item,
            isWatchlist: isWatchlist,
            isTogglingWatchlist: isTogglingWatchlist,
            trailerAvailable: localTrailer != nil || trailerURL != nil,
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
            guard let nextEpisode else { return "Play" }
            let season = nextEpisode.parentIndexNumber ?? 1
            let episode = nextEpisode.indexNumber ?? 1
            return "Play S\(season) E\(episode)"
        }

        let hasProgress = (item.userData?.playbackPositionTicks ?? 0) > 0 && item.userData?.isPlayed != true
        return hasProgress ? "Resume" : "Play"
    }

    // MARK: - Actions

    private func play() {
        let target = item.type == .series ? nextEpisode : item
        guard let target else { return }
        startPlayback(for: target)
    }

    private func playTrailer() {
        if let localTrailer {
            startPlayback(for: localTrailer)
        } else if let trailerURL {
            openURL(trailerURL)
        }
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

    private func loadLocalTrailer() async {
        guard let client = appState.client, let id = item.id, (item.localTrailerCount ?? 0) > 0 else { return }
        do {
            let trailers = try await client.send(Paths.getLocalTrailers(itemID: id, userID: appState.currentUser?.id)).value
            localTrailer = trailers.first
        } catch {
            localTrailer = nil
        }
    }

    private func loadNextEpisode() async {
        guard let client = appState.client, let seriesID = item.id else { return }
        do {
            let nextUp = try await client.send(Paths.getNextUp(parameters: .init(
                userID: appState.currentUser?.id,
                limit: 1,
                seriesID: seriesID
            ))).value
            if let episode = nextUp.items?.first {
                nextEpisode = episode
                return
            }

            let episodes = try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: .init(
                userID: appState.currentUser?.id,
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
                seasonID: seasonID,
                enableUserData: true
            ))).value
            episodes = result.items ?? []
        } catch {
            episodes = []
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
