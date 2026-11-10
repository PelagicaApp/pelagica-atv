//
//  LibraryItemsView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct LibraryItemsView: View {
    @EnvironmentObject private var appState: AppState

    let title: String
    let emptyMessage: String
    let isFilterable: Bool

    @StateObject private var model: LibraryItemsModel

    init(library: BaseItemDto) {
        title = library.name ?? i18n.t("item:unknown_library")
        emptyMessage = i18n.t("library:no_items_description")
        isFilterable = library.collectionType == .movies || library.collectionType == .tvshows
        _model = StateObject(wrappedValue: LibraryItemsModel(query: .library(id: library.id)))
    }

    init(genre: GenreRoute) {
        title = genre.name
        emptyMessage = i18n.t("library:no_items_genre_description")
        isFilterable = true
        _model = StateObject(wrappedValue: LibraryItemsModel(query: .genre(id: genre.id)))
    }

    init(studio: StudioRoute) {
        title = studio.name
        emptyMessage = i18n.t("library:no_items_description")
        isFilterable = true
        _model = StateObject(wrappedValue: LibraryItemsModel(query: .studio(id: studio.id)))
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] { CardMetrics.gridColumns(minimum: 104, spacing: 12, sizeClass) }

    var body: some View {
        ScrollView {
            if let errorMessage = model.errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            } else if model.items.isEmpty && !model.isLoadingMore {
                ContentUnavailableView(i18n.t("library:no_items_title"), systemImage: "film.stack", description: Text(emptyMessage))
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(model.items) { item in
                        PosterCard(item: item, width: nil)
                            .onAppear { model.loadMoreIfNeeded(current: item) }
                    }
                }
                .padding()

                if model.isLoadingMore {
                    ProgressView().padding()
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isFilterable { filterMenu }
                sortMenu
            }
        }
        .task(id: model.queryKey) {
            model.bind(appState: appState)
            await model.reload()
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker(i18n.t("settings:sort_by"), selection: $model.sortBy) {
                Label(i18n.t("library:sort_name"), systemImage: "textformat").tag(ItemSortBy.name)
                Label(i18n.t("settings:collection_sort_Random"), systemImage: "dice").tag(ItemSortBy.random)
                Label(i18n.t("library:sort_community_rating"), systemImage: "star").tag(ItemSortBy.communityRating)
                Label(i18n.t("library:sort_date_added"), systemImage: "calendar.badge.plus").tag(ItemSortBy.dateCreated)
                Label(i18n.t("item:release_date"), systemImage: "calendar").tag(ItemSortBy.premiereDate)
            }

            Picker(i18n.t("settings:sort_order"), selection: $model.sortOrder) {
                Label(i18n.t("ascending"), systemImage: "arrow.up").tag(JellyfinAPI.SortOrder.ascending)
                Label(i18n.t("descending"), systemImage: "arrow.down").tag(JellyfinAPI.SortOrder.descending)
            }
        } label: {
            Label(i18n.t("settings:sort_by"), systemImage: "arrow.up.arrow.down")
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker(i18n.t("library:filter"), selection: $model.watchFilter) {
                Label(i18n.t("live:filter_all"), systemImage: "square.grid.2x2").tag(LibraryItemsModel.WatchFilter.all)
                Label(i18n.t("library:filter_unwatched"), systemImage: "circle").tag(LibraryItemsModel.WatchFilter.unwatched)
                Label(i18n.t("library:filter_in_progress"), systemImage: "circle.lefthalf.filled").tag(LibraryItemsModel.WatchFilter.inProgress)
                Label(i18n.t("library:filter_watched"), systemImage: "checkmark.circle.fill").tag(LibraryItemsModel.WatchFilter.watched)
            }
        } label: {
            Label(
                i18n.t("library:filter"),
                systemImage: model.watchFilter == .all
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }
}
