//
//  HomeView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configStore: AppConfigStore
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @StateObject private var model = HomeModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if model.hasMediaBarSection {
                        if model.mediaBarItems.isEmpty {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .aspectRatio(HomeHero.aspectRatio(for: sizeClass), contentMode: .fit)
                        } else {
                            HomeHero(
                                items: model.mediaBarItems,
                                showFavoriteButton: model.mediaBarShowFavoriteButton,
                                showWatchlistButton: model.mediaBarShowWatchlistButton
                            )
                        }
                    }

                    ForEach(model.slots) { slot in
                        if slot.isLoading {
                            PlaceholderShelf(title: slot.title, isLandscape: slot.skeletonKind == .landscape)
                        } else {
                            ForEach(slot.rows) { row in
                                if !row.isEmpty {
                                    HomeRowView(row: row)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .overlay {
                if model.isLoadingConfig { ProgressView() }
            }
            .ignoresSafeArea(edges: model.hasMediaBarSection ? .top : [])
            .navigationTitle(model.hasMediaBarSection ? "" : i18n.t("home:title"))
            .toolbar(model.hasMediaBarSection ? .hidden : .automatic, for: .navigationBar)
            .refreshable { await model.loadHome() }
            .appDestinations()
        }
        .task(id: seerrStore.isLoggedIn) {
            model.bind(appState: appState, configStore: configStore, seerrStore: seerrStore)
            await model.loadHome()
        }
        .onChange(of: appState.watchStateVersion) {
            Task { await model.refreshProgressRows() }
        }
    }
}

private struct HomeRowView: View {
    let row: HomeRow

    var body: some View {
        switch row.kind {
        case .poster(let detailText, let useThumb, _):
            Shelf(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    let item = row.items[index]
                    if useThumb {
                        LandscapeCard(item: item, detailText: detailText(item))
                    } else {
                        PosterCard(item: item, detailText: detailText(item))
                    }
                }
            }

        case .recommended(let recommendations, let showSimilarity):
            Shelf(title: row.title) {
                ForEach(recommendations.indices, id: \.self) { index in
                    let recommendation = recommendations[index]
                    PosterCard(item: recommendation.item, similarity: showSimilarity ? recommendation.similarity : nil)
                }
            }

        case .continueStyle(let titleLine, let detailLines, let useSeriesImage):
            Shelf(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    let item = row.items[index]
                    LandscapeCard(
                        item: item,
                        title: HomeModel.titleLineText(for: item, titleLine: titleLine),
                        detailText: HomeModel.detailLineText(for: item, lines: detailLines),
                        playsOnTap: true,
                        useSeriesImage: useSeriesImage
                    )
                }
            }

        case .library:
            Shelf(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    LibraryCard(library: row.items[index], width: 220)
                }
            }

        case .genres(let genres):
            Shelf(title: row.title) {
                ForEach(genres) { genre in
                    GenreCard(genre: genre)
                }
            }

        case .studios(let studios):
            Shelf(title: row.title) {
                ForEach(studios) { studio in
                    StudioCard(studio: studio)
                }
                NavigationLink(value: StudiosRoute()) {
                    StudioCardFrame { StudioCardLabel(text: i18n.t("home:more")) }
                }
                .buttonStyle(.plain)
            }

        case .seerr(let items):
            SeerrShelf(title: row.title, items: items)
        }
    }
}
