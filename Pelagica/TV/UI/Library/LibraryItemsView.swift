//
//  LibraryItemsView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct LibraryItemsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let title: String
    let emptyMessage: String
    let isFilterable: Bool

    @StateObject private var model: LibraryItemsModel

    init(library: BaseItemDto) {
        title = library.name ?? i18n.t("item:unknown_library")
        emptyMessage = i18n.t("library:no_items_description")
        _model = StateObject(wrappedValue: LibraryItemsModel(query: .library(id: library.id)))
        isFilterable = library.collectionType == .movies || library.collectionType == .tvshows
    }

    init(genre: GenreRoute) {
        title = genre.name
        emptyMessage = i18n.t("library:no_items_genre_description")
        _model = StateObject(wrappedValue: LibraryItemsModel(query: .genre(id: genre.id)))
        isFilterable = true
    }

    init(studio: StudioRoute) {
        title = studio.name
        emptyMessage = i18n.t("library:no_items_description")
        _model = StateObject(wrappedValue: LibraryItemsModel(query: .studio(id: studio.id)))
        isFilterable = true
    }

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 40)]

    var body: some View {
        ZStack {
            PelagicaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HStack(spacing: 24) {
                        Text(title)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        if isFilterable {
                            filterMenu
                        }
                        sortMenu
                    }
                    .focusSection()

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    } else if (model.items.isEmpty){
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 60) {
                            ForEach(model.items) { item in
                                ItemCard(item: item)
                                    .onAppear { model.loadMoreIfNeeded(current: item) }
                            }

                            if model.isLoadingMore {
                                ForEach(0..<model.prefetchThreshold, id: \.self) { _ in
                                    SkeletonView()
                                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                        .focusSection()
                    }
                }
                .padding(60)
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
                Label(i18n.t("settings:collection_sort_Random"), systemImage: "dice.fill").tag(ItemSortBy.random)
                Label(i18n.t("library:sort_community_rating"), systemImage: "star.fill").tag(ItemSortBy.communityRating)
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

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(i18n.t("library:no_items_title"))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(emptyMessage)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            
            Button {
                dismiss()
            } label: {
                Text(i18n.t("back"))
                    .font(.system(size: 20, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.card)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

#Preview {
    LibraryItemsView(library: BaseItemDto(name: "Movies"))
        .environmentObject(AppState())
}
