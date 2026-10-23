//
//  SearchModel.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI

@MainActor
final class SearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [BaseItemDto] = []
    @Published private(set) var seerrResults: [SeerrMediaItem] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let resultsCount = 25

    private var appState: AppState?
    private var seerrStore: SeerrStore?

    func bind(appState: AppState, seerrStore: SeerrStore) {
        self.appState = appState
        self.seerrStore = seerrStore
    }

    var hasNoResults: Bool {
        results.isEmpty && seerrResults.isEmpty
    }

    /// Runs the current query after a short debounce. Call from `.task(id: query)` so typing cancels it.
    func search() async {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        results = []
        seerrResults = []
        isLoading = true
        async let seerrSearch: Void = searchSeerr()
        await searchJellyfin()
        await seerrSearch
        isLoading = false
    }

    private func searchSeerr() async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let seerrStore else { return }
        let items = await seerrStore.items { try await $0.search(query: query) }
        guard !Task.isCancelled else { return }
        seerrResults = items.filter { $0.status != .available }
    }

    private func searchJellyfin() async {
        guard let client = appState?.client else { return }
        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: appState?.currentUser?.id,
                locationTypes: [LocationType.fileSystem],
                limit: resultsCount,
                isRecursive: true,
                searchTerm: query,
                fields: [.overview, .parentID],
                includeItemTypes: [.movie, .series],
                enableUserData: true,
            ))).value
            results = result.items ?? []
        } catch is CancellationError {
        } catch {
            errorMessage = i18n.t("search:error_occurred_while_searching")
        }
    }
}
