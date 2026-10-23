//
//  LibraryItemsModel.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI

@MainActor
final class LibraryItemsModel: ObservableObject {
    enum Query {
        case library(id: String?)
        case genre(id: String)
        case studio(id: String)
    }

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

    let query: Query

    @Published private(set) var items: [BaseItemDto] = []
    @Published private(set) var totalCount: Int?
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var sortBy: ItemSortBy = .dateCreated
    @Published var sortOrder: JellyfinAPI.SortOrder = .descending
    @Published var watchFilter: WatchFilter = .all

    private var loadedQueryKey: String?
    private var inProgressIDs: [String]?

    let prefetchThreshold = 8
    private let batchSize = 48

    private var appState: AppState?

    init(query: Query) {
        self.query = query
    }

    func bind(appState: AppState) {
        self.appState = appState
    }

    var hasMore: Bool {
        guard let totalCount else { return true }
        return items.count < totalCount
    }

    /// Changes whenever sorting or filtering does, so the view can reload with `.task(id:)`.
    var queryKey: String { "\(sortBy.rawValue)|\(sortOrder.rawValue)|\(watchFilter.rawValue)" }

    func reload() async {
        guard loadedQueryKey != queryKey else { return }
        items = []
        inProgressIDs = nil
        errorMessage = nil
        totalCount = nil
        isLoadingMore = true
        await loadMore()
    }

    func loadMoreIfNeeded(current item: BaseItemDto) {
        guard hasMore, !isLoadingMore else { return }
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard itemIndex >= items.count - prefetchThreshold else { return }

        isLoadingMore = true
        Task { await loadMore() }
    }

    private func loadMore() async {
        let requestedQueryKey = queryKey
        defer { isLoadingMore = false }
        guard let client = appState?.client else { return }
        var parameters = Paths.GetItemsParameters(
            userID: appState?.currentUser?.id,
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
        let userID = appState?.currentUser?.id
        let query = query
        func fetch(types: [BaseItemKind], filter: ItemFilter) async throws -> [BaseItemDto] {
            var parameters = Paths.GetItemsParameters(userID: userID)
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
}
