//
//  HomeTabView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configStore: AppConfigStore
    @EnvironmentObject private var seerrStore: SeerrStore

    @StateObject private var model = HomeModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ZStack {
                    PelagicaBackground()

                    if model.isLoadingConfig {
                        ProgressView()
                            .tint(.white)
                    } else {
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 30) {
                                    if model.hasMediaBarSection {
                                        Group {
                                            if model.mediaBarItems.isEmpty {
                                                SkeletonView()
                                            } else {
                                                HomeMediaBar(
                                                    items: model.mediaBarItems,
                                                    showFavoriteButton: model.mediaBarShowFavoriteButton,
                                                    showWatchlistButton: model.mediaBarShowWatchlistButton,
                                                    onButtonFocused: {
                                                        withAnimation {
                                                            scrollProxy.scrollTo(Self.topScrollAnchor, anchor: .top)
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .frame(height: proxy.size.height * 0.82)
                                        .focusSection()
                                        .id(Self.topScrollAnchor)

                                        Color.clear.frame(height: 40)
                                    }

                                    ForEach(model.slots) { slot in
                                        if slot.isLoading {
                                            loadingRow(kind: slot.skeletonKind, title: slot.title)
                                                .focusSection()
                                        } else {
                                            ForEach(slot.rows) { row in
                                                if !row.isEmpty {
                                                    rowView(for: row)
                                                        .focusSection()
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, model.hasMediaBarSection ? 0 : 60)
                                .padding(.bottom, 60)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: model.hasMediaBarSection ? [.top, .horizontal] : [])
            .pelagicaDestinations()
            .navigationDestination(for: GenreRoute.self) { route in
                LibraryItemsView(genre: route)
            }
            .navigationDestination(for: StudioRoute.self) { route in
                LibraryItemsView(studio: route)
            }
            .navigationDestination(for: StudiosRoute.self) { _ in
                StudiosView()
            }
        }
        .onDisappear { path = NavigationPath() }
        // Reloads when Seerr is logged in or out from Settings, so its rows appear or disappear
        .task(id: seerrStore.isLoggedIn) {
            model.bind(appState: appState, configStore: configStore, seerrStore: seerrStore)
            await model.loadHome()
        }
        .onChange(of: appState.watchStateVersion) {
            Task { await model.refreshProgressRows() }
        }
    }

    private static let topScrollAnchor = "homeTop"

    private func loadingRow(kind: HomeSlot.SkeletonKind, title: String?) -> some View {
        HomeSectionRow(title: title ?? "", isLoadingTitle: title == nil) {
            ForEach(0..<5, id: \.self) { _ in
                switch kind {
                case .poster:
                    SkeletonView()
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(width: 280)
                case .landscape:
                    SkeletonView()
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(width: 420)
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(for row: HomeRow) -> some View {
        switch row.kind {
        case .poster(let detailText, let useThumb, let autoPlayTrailers):
            HomeSectionRow(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    ItemCard(item: row.items[index], detailText: detailText, useThumb: useThumb, autoPlayTrailer: autoPlayTrailers)
                        .frame(width: useThumb ? 420 : 280)
                }
            }

        case .recommended(let recommendations, let showSimilarity):
            HomeSectionRow(title: row.title) {
                ForEach(recommendations.indices, id: \.self) { index in
                    let recommendation = recommendations[index]
                    ItemCard(
                        item: recommendation.item,
                        similarity: showSimilarity ? recommendation.similarity : nil
                    )
                    .frame(width: 280)
                }
            }

        case .continueStyle(let titleLine, let detailLines, let useSeriesImage):
            HomeSectionRow(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    let item = row.items[index]
                    ContinueWatchingCard(
                        item: item,
                        titleText: HomeModel.titleLineText(for: item, titleLine: titleLine),
                        detailText: HomeModel.detailLineText(for: item, lines: detailLines),
                        useSeriesImage: useSeriesImage
                    )
                    .frame(width: 420)
                }
            }

        case .library:
            HomeSectionRow(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    HomeLibraryCard(library: row.items[index])
                        .frame(width: 420)
                }
            }

        case .genres(let genres):
            HomeSectionRow(title: row.title) {
                ForEach(genres) { genre in
                    HomeGenreCard(genre: genre)
                        .frame(width: 420)
                }
            }

        case .studios(let studios):
            HomeSectionRow(title: row.title) {
                ForEach(studios) { studio in
                    HomeStudioCard(studio: studio)
                        .frame(width: 420)
                }
                HomeStudiosMoreCard()
                    .frame(width: 420)
            }

        case .seerr(let items):
            HomeSectionRow(title: row.title) {
                ForEach(items) { item in
                    SeerrItemCard(item: item)
                        .frame(width: 280)
                }
            }
        }
    }
}

#Preview {
    HomeTabView()
        .environmentObject(AppState())
        .environmentObject(AppConfigStore())
        .environmentObject(SeerrStore())
}
