//
//  LibraryItemsView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct LibraryItemsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let title: String
    let emptyMessage: String
    let query: Query
    let isFilterable: Bool

    enum Query {
        case library(id: String?)
        case genre(id: String)
        case studio(id: String)
    }

    init(library: BaseItemDto) {
        title = library.name ?? i18n.t("item:unknown_library")
        emptyMessage = i18n.t("library:no_items_description")
        query = .library(id: library.id)
        isFilterable = library.collectionType == .movies || library.collectionType == .tvshows
    }

    init(genre: GenreRoute) {
        title = genre.name
        emptyMessage = i18n.t("library:no_items_genre_description")
        query = .genre(id: genre.id)
        isFilterable = true
    }

    init(studio: StudioRoute) {
        title = studio.name
        emptyMessage = i18n.t("library:no_items_description")
        query = .studio(id: studio.id)
        isFilterable = true
    }

    @State private var items: [BaseItemDto] = []
    @State private var totalCount: Int?
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var sortBy: ItemSortBy = .dateCreated
    @State private var sortOrder: JellyfinAPI.SortOrder = .descending
    @State private var watchFilter: WatchFilter = .all
    @State private var loadedQueryKey: String?
    @State private var inProgressIDs: [String]?

    enum WatchFilter: String, CaseIterable {
        case all
        case unwatched
        case inProgress
        case watched

        var itemFilter: ItemFilter? {
            switch self {
            case .all: nil
            case .unwatched: .isUnplayed
            case .inProgress: .isUnplayed
            case .watched: .isPlayed
            }
        }
    }

    /// How many items from the end of the loaded list trigger fetching the next batch.
    private let prefetchThreshold = 8
    private let batchSize = 48
    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 40)]

    private var hasMore: Bool {
        guard let totalCount else { return true }
        return items.count < totalCount
    }

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

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    } else if (items.isEmpty){
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 60) {
                            ForEach(items) { item in
                                ItemCard(item: item)
                                    .onAppear { loadMoreIfNeeded(current: item) }
                            }

                            if isLoadingMore {
                                ForEach(0..<prefetchThreshold, id: \.self) { _ in
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
        .task(id: queryKey) {
            guard loadedQueryKey != queryKey else { return }
            items = []
            inProgressIDs = nil
            errorMessage = nil
            totalCount = nil
            isLoadingMore = true
            await loadMore()
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker(i18n.t("settings:sort_by"), selection: $sortBy) {
                Label(i18n.t("library:sort_name"), systemImage: "textformat").tag(ItemSortBy.name)
                Label(i18n.t("settings:collection_sort_Random"), systemImage: "dice.fill").tag(ItemSortBy.random)
                Label(i18n.t("library:sort_community_rating"), systemImage: "star.fill").tag(ItemSortBy.communityRating)
                Label(i18n.t("library:sort_date_added"), systemImage: "calendar.badge.plus").tag(ItemSortBy.dateCreated)
                Label(i18n.t("item:release_date"), systemImage: "calendar").tag(ItemSortBy.premiereDate)
            }

            Picker(i18n.t("settings:sort_order"), selection: $sortOrder) {
                Label(i18n.t("ascending"), systemImage: "arrow.up").tag(JellyfinAPI.SortOrder.ascending)
                Label(i18n.t("descending"), systemImage: "arrow.down").tag(JellyfinAPI.SortOrder.descending)
            }
        } label: {
            Label(i18n.t("settings:sort_by"), systemImage: "arrow.up.arrow.down")
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker(i18n.t("library:filter"), selection: $watchFilter) {
                Label(i18n.t("live:filter_all"), systemImage: "square.grid.2x2").tag(WatchFilter.all)
                Label(i18n.t("library:filter_unwatched"), systemImage: "circle").tag(WatchFilter.unwatched)
                Label(i18n.t("library:filter_in_progress"), systemImage: "circle.lefthalf.filled").tag(WatchFilter.inProgress)
                Label(i18n.t("library:filter_watched"), systemImage: "checkmark.circle.fill").tag(WatchFilter.watched)
            }
        } label: {
            Label(
                i18n.t("library:filter"),
                systemImage: watchFilter == .all
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

    private func loadMoreIfNeeded(current item: BaseItemDto) {
        guard hasMore, !isLoadingMore else { return }
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard itemIndex >= items.count - prefetchThreshold else { return }

        isLoadingMore = true
        Task { await loadMore() }
    }

    private func loadMore() async {
        let requestedQueryKey = queryKey
        defer { isLoadingMore = false }
        guard let client = appState.client else { return }
        var parameters = Paths.GetItemsParameters(
            userID: appState.currentUser?.id,
            startIndex: items.count,
            limit: batchSize,
            sortOrder: [sortOrder],
            sortBy: [sortBy]
        )
        if let itemFilter = watchFilter.itemFilter {
            parameters.filters = [itemFilter]
        }
        switch query {
        case .library(let id):
            guard let id else { return }
            parameters.isRecursive = false
            parameters.parentID = id
        case .genre(let id):
            parameters.isRecursive = true
            parameters.includeItemTypes = [.movie, .series]
            parameters.excludeItemTypes = [.collectionFolder]
            parameters.genreIDs = [id]
        case .studio(let id):
            parameters.isRecursive = true
            parameters.includeItemTypes = [.movie, .series]
            parameters.excludeItemTypes = [.collectionFolder]
            parameters.studioIDs = [id]
        }
        do {
            if watchFilter == .inProgress {
                let ids: [String]
                if let inProgressIDs {
                    ids = inProgressIDs
                } else {
                    ids = try await fetchInProgressIDs(client: client)
                    guard requestedQueryKey == queryKey else { return }
                    inProgressIDs = ids
                }
                guard !ids.isEmpty else {
                    loadedQueryKey = requestedQueryKey
                    totalCount = 0
                    return
                }
                parameters.ids = ids
            }
            let result = try await client.send(Paths.getItems(parameters: parameters)).value
            guard requestedQueryKey == queryKey else { return }
            items.append(contentsOf: result.items ?? [])
            loadedQueryKey = requestedQueryKey
            totalCount = result.totalRecordCount ?? items.count
        } catch is CancellationError {
        } catch {
            errorMessage = i18n.t("library:load_items_error")
        }
    }

    private func fetchInProgressIDs(client: JellyfinClient) async throws -> [String] {
        func fetch(types: [BaseItemKind], filter: ItemFilter) async throws -> [BaseItemDto] {
            var parameters = Paths.GetItemsParameters(userID: appState.currentUser?.id)
            parameters.isRecursive = true
            parameters.includeItemTypes = types
            parameters.filters = [filter]
            parameters.enableUserData = false
            parameters.enableImages = false
            if case .library(let id) = query {
                parameters.parentID = id
            }
            return try await client.send(Paths.getItems(parameters: parameters)).value.items ?? []
        }

        let resumable = try await fetch(types: [.movie, .episode], filter: .isResumable)
        let playedEpisodes = try await fetch(types: [.episode], filter: .isPlayed)

        var ids = Set<String>()
        for item in resumable + playedEpisodes {
            if item.type == .episode {
                if let seriesID = item.seriesID { ids.insert(seriesID) }
            } else if let id = item.id {
                ids.insert(id)
            }
        }
        return Array(ids)
    }

    private var queryKey: String { "\(sortBy.rawValue)|\(sortOrder.rawValue)|\(watchFilter.rawValue)" }
}

#Preview {
    LibraryItemsView(library: BaseItemDto(name: "Movies"))
        .environmentObject(AppState())
}
