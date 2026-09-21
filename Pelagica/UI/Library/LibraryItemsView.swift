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

    enum Query {
        case library(BaseItemDto)
        case genre(id: String)
    }

    init(library: BaseItemDto) {
        title = library.name ?? "Library"
        emptyMessage = "This collection doesn't have any items in it."
        query = .library(library)
    }

    init(genre: GenreRoute) {
        title = genre.name
        emptyMessage = "There's nothing in this genre."
        query = .genre(id: genre.id)
    }

    @State private var items: [BaseItemDto] = []
    @State private var container: BaseItemDto?
    @State private var totalCount: Int?
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var sortBy: ItemSortBy = .dateCreated
    @State private var sortOrder: JellyfinAPI.SortOrder = .descending
    @State private var loadGeneration = UUID()

    private let prefetchThreshold = 8
    private let batchSize = 48
    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 40)]

    private var hasMore: Bool {
        guard let totalCount else { return true }
        return items.count < totalCount
    }

    private var preservesOrder: Bool {
        if case .library(let item) = query {
            let type = container?.type ?? item.type
            return type == .playlist || type == .season || type == .musicAlbum
        }
        return false
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HStack {
                        Button { dismiss() } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        Text(title)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        if !preservesOrder { sortMenu }
                    }
                    .focusSection()

                    if let errorMessage {
                        VStack(spacing: 24) {
                            Text(errorMessage).foregroundStyle(.secondary)
                            Button("Try Again") {
                                Task { await loadMore(generation: loadGeneration) }
                            }
                        }
                        .focusSection()
                    }
                    if items.isEmpty && !isLoadingMore && errorMessage == nil {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 60) {
                            // Playlist entries can repeat the same media ID. The offset identifies each occurrence.
                            ForEach(items.indices, id: \.self) { index in
                                ItemCard(item: items[index])
                                    .onAppear { loadMoreIfNeeded(at: index) }
                            }
                            if isLoadingMore {
                                // Keep loading IDs disjoint from real playlist positions.
                                ForEach(-prefetchThreshold..<0, id: \.self) { _ in
                                    SkeletonView()
                                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                        .focusSection()
                        if hasMore && !isLoadingMore && errorMessage == nil {
                            Button("Load More") {
                                Task { await loadMore(generation: loadGeneration) }
                            }
                        }
                    }
                }
                .padding(60)
            }
        }
        .task(id: loadKey) {
            let generation = UUID()
            loadGeneration = generation
            items = []
            container = nil
            totalCount = nil
            errorMessage = nil
            isLoadingMore = false
            await loadMore(generation: generation)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortBy) {
                Label("Name", systemImage: "textformat").tag(ItemSortBy.name)
                Label("Community Rating", systemImage: "star.fill").tag(ItemSortBy.communityRating)
                Label("Date Added", systemImage: "calendar.badge.plus").tag(ItemSortBy.dateCreated)
                Label("Release Date", systemImage: "calendar").tag(ItemSortBy.premiereDate)
            }
            Picker("Order", selection: $sortOrder) {
                Label("Ascending", systemImage: "arrow.up").tag(JellyfinAPI.SortOrder.ascending)
                Label("Descending", systemImage: "arrow.down").tag(JellyfinAPI.SortOrder.descending)
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing here yet")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            Text(emptyMessage)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Button("Go Back") { dismiss() }
                .buttonStyle(.card)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func loadMoreIfNeeded(at index: Int) {
        guard hasMore, !isLoadingMore, errorMessage == nil,
              index >= items.count - prefetchThreshold else { return }
        let generation = loadGeneration
        Task { await loadMore(generation: generation) }
    }

    private func loadMore(generation: UUID) async {
        guard generation == loadGeneration, !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        errorMessage = nil
        defer {
            if generation == loadGeneration { isLoadingMore = false }
        }
        guard let client = appState.client else {
            errorMessage = "Connect to your server to browse this collection."
            return
        }
        do {
            if case .library(let item) = query, container == nil {
                guard let id = item.id else { throw BrowseError.missingID }
                let full = try await client.sendItems(Paths.getItem(itemID: id, userID: appState.currentUser?.id)).value
                guard generation == loadGeneration, !Task.isCancelled else { return }
                container = full
            }
            let request = try itemsRequest(startIndex: items.count)
            let result = try await client.sendItems(request).value
            guard generation == loadGeneration, !Task.isCancelled else { return }
            let page = result.items ?? []
            items.append(contentsOf: page)
            // Stop on an empty page even if the server returned a stale total.
            totalCount = page.isEmpty ? items.count : result.totalRecordCount
            if totalCount == nil && page.count < batchSize { totalCount = items.count }
        } catch is CancellationError {
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            errorMessage = "Couldn't load items. Please try again."
        }
    }

    private func itemsRequest(startIndex: Int) throws -> Request<BaseItemDtoQueryResult> {
        let userID = appState.currentUser?.id
        let sortKeys: [ItemSortBy] = sortBy == .sortName ? [.sortName] : [sortBy, .sortName]
        var parameters = Paths.GetItemsParameters(
            userID: userID,
            startIndex: startIndex,
            limit: batchSize,
            isRecursive: false,
            sortOrder: [sortOrder],
            fields: [.overview, .parentID],
            sortBy: sortKeys,
            enableUserData: true,
            enableTotalRecordCount: true
        )
        switch query {
        case .library:
            guard let container, let id = container.id else { throw BrowseError.missingID }
            if container.collectionType == .livetv {
                return Paths.getLiveTvChannels(parameters: .init(
                    userID: userID, startIndex: startIndex, limit: batchSize,
                    fields: [.overview], enableUserData: true,
                    sortBy: sortKeys, sortOrder: sortOrder
                ))
            }
            switch container.type {
            case .playlist:
                return Paths.getPlaylistItems(playlistID: id, parameters: .init(
                    userID: userID, startIndex: startIndex, limit: batchSize,
                    fields: [.overview, .parentID], enableUserData: true
                ))
            case .musicArtist:
                parameters.isRecursive = true
                parameters.artistIDs = [id]
                parameters.includeItemTypes = [.musicAlbum, .audio, .musicVideo]
            case .musicAlbum:
                parameters.isRecursive = true
                parameters.albumIDs = [id]
                parameters.includeItemTypes = [.audio]
                parameters.sortBy = [.parentIndexNumber, .indexNumber, .sortName]
                parameters.sortOrder = [.ascending]
            case .season:
                guard let seriesID = container.seriesID ?? container.parentID else { throw BrowseError.missingID }
                return Paths.getEpisodes(seriesID: seriesID, parameters: .init(
                    userID: userID, fields: [.overview, .parentID], seasonID: id,
                    startIndex: startIndex, limit: batchSize, enableUserData: true
                ))
            default:
                parameters.parentID = id
            }
        case .genre(let id):
            parameters.isRecursive = true
            parameters.includeItemTypes = [.movie, .series]
            parameters.excludeItemTypes = [.collectionFolder]
            parameters.genreIDs = [id]
        }
        return Paths.getItems(parameters: parameters)
    }

    private var loadKey: String {
        let identity: String
        switch query {
        case .library(let item): identity = "library|\(item.id ?? "")"
        case .genre(let id): identity = "genre|\(id)"
        }
        return "\(identity)|\(sortBy.rawValue)|\(sortOrder.rawValue)"
    }

    private enum BrowseError: Error { case missingID }
}

#Preview {
    LibraryItemsView(library: BaseItemDto(id: "preview", name: "Library"))
        .environmentObject(AppState())
}
