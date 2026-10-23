//
//  ItemDetailView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configStore: AppConfigStore
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.openURL) private var openURL

    @StateObject private var model: ItemDetailModel

    @Namespace private var heroNamespace
    @Namespace private var seasonsNamespace
    @Namespace private var episodesNamespace
    @Namespace private var similarNamespace
    @Namespace private var boxSetNamespace
    @FocusState private var isPlayButtonFocused: Bool

    init(item: BaseItemDto) {
        _model = StateObject(wrappedValue: ItemDetailModel(item: item))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 60) {
                    heroSection
                        .frame(height: proxy.size.height * 0.87)
                        .focusScope(heroNamespace)
                        .focusSection()

                    if model.item.type == .series {
                        ItemDetailEpisodesSection(
                            seasons: model.seasons,
                            selectedSeasonID: $model.selectedSeasonID,
                            episodes: model.episodes,
                            seasonsNamespace: seasonsNamespace,
                            episodesNamespace: episodesNamespace,
                            onPlayEpisode: model.startPlayback,
                            onTogglePlayed: model.togglePlayed,
                            onSelectSeason: { await model.loadEpisodes(seasonID: $0) }
                        )
                    }

                    if model.item.type == .boxSet, !model.boxSetItems.isEmpty {
                        ItemDetailBoxSetSection(
                            items: model.boxSetItems,
                            nextItemID: model.nextBoxSetItem?.id,
                            namespace: boxSetNamespace
                        )
                    }

                    if model.localTrailers.count > 1 {
                        ItemTrailersSection(
                            trailers: model.localTrailers,
                            onPlayTrailer: model.startPlayback
                        )
                    }
                    
                    if let people = model.item.people, !people.isEmpty {
                        ItemDetailsPeopleSection(people: people)
                    }

                    if !model.collectionItems.isEmpty {
                        ItemDetailCollectionsSection(collectionItems: model.collectionItems)
                    }

                    if !model.similarItems.isEmpty {
                        ItemDetailSimilarSection(items: model.similarItems, namespace: similarNamespace)
                    }

                    if !model.seerrRecommendations.isEmpty {
                        SeerrItemsRow(title: i18n.t("item:recommendations"), items: model.seerrRecommendations)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .background(PelagicaBackground())
        .task {
            model.bind(appState: appState, configStore: configStore, seerrStore: seerrStore)
            await model.load()
        }
        .onDisappear {
            model.stopThemeSong()
        }
        .fullScreenCover(item: $model.playbackTarget) { target in
            VideoPlayerView(item: target.item, startTicks: target.startTicks)
                .ignoresSafeArea()
        }
        .onChange(of: model.playbackTarget == nil) { wasNilBefore, isNilNow in
            guard isNilNow, !wasNilBefore else { return }
            Task { await model.playbackEnded() }
        }
    }

    private var heroSection: some View {
        ItemDetailHeroSection(
            item: model.item,
            isWatchlist: model.isWatchlist,
            isTogglingWatchlist: model.isTogglingWatchlist,
            isFavorite: model.isFavorite,
            isTogglingFavorite: model.isTogglingFavorite,
            isPlayed: model.isPlayed,
            isTogglingPlayed: model.isTogglingPlayed,
            trailerAvailable: model.trailerAvailable,
            playLabel: model.playLabel,
            namespace: heroNamespace,
            isPlayButtonFocused: $isPlayButtonFocused,
            onPlay: model.play,
            onPlayTrailer: playTrailer,
            onToggleWatchlist: model.toggleWatchlist,
            onToggleFavorite: model.toggleFavorite,
            onTogglePlayed: model.toggleItemPlayed,
            seerrRoute: model.seerrRoute
        )
    }

    private func playTrailer() {
        if let trailerURL = model.playTrailer() {
            openURL(trailerURL)
        }
    }
}

#Preview {
    ItemDetailView(item: BaseItemDto(name: "Preview Item", overview: "A short preview overview."))
        .environmentObject(AppState())
        .environmentObject(AppConfigStore())
        .environmentObject(SeerrStore())
}
