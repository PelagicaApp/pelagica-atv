//
//  SeerrItemDetailModel.swift
//  Pelagica
//

import Combine
import Foundation
import JellyfinAPI

@MainActor
final class SeerrItemDetailModel: ObservableObject {
    enum RequestResult {
        case success
        case failure
    }

    let route: SeerrItemRoute

    @Published private(set) var details: SeerrDetails?
    @Published private(set) var loadFailed = false
    @Published private(set) var recommendations: [SeerrMediaItem] = []
    @Published private var deselectedSeasons: Set<Int> = []
    @Published private(set) var isRequesting = false
    @Published private(set) var requestResult: RequestResult?

    private var seerrStore: SeerrStore?

    init(route: SeerrItemRoute) {
        self.route = route
    }

    func bind(seerrStore: SeerrStore) {
        self.seerrStore = seerrStore
    }

    func load() async {
        await loadDetails()
        guard let seerrStore else { return }
        let route = route
        recommendations = await seerrStore.items {
            try await $0.recommendations(mediaType: route.mediaType, tmdbID: route.tmdbID)
        }
    }

    func toggleSeason(_ season: SeerrSeason) {
        guard requestableSeasons.contains(season) else { return }
        if selectedSeasons.contains(season.seasonNumber) {
            deselectedSeasons.insert(season.seasonNumber)
        } else {
            deselectedSeasons.remove(season.seasonNumber)
        }
    }

    var requestLabel: String {
        if isRequesting { return i18n.t("seerr:seerr_requesting") }
        if details?.mediaType == .tv, !selectedSeasons.isEmpty {
            return i18n.t("seerr:seerr_request_seasons_count", count: selectedSeasons.count)
        }
        return i18n.t("seerr:seerr_request")
    }

    var libraryRoute: ItemDetailRoute? {
        guard let details, let jellyfinID = details.mediaInfo?.jellyfinMediaId,
              details.status == .available || details.status == .partiallyAvailable else { return nil }
        return ItemDetailRoute(item: BaseItemDto(id: jellyfinID, name: details.title))
    }

    /// Season availability, with seasons that have an open request counted as pending.
    var seasonStatuses: [Int: SeerrMediaStatus] {
        var statuses: [Int: SeerrMediaStatus] = [:]
        for season in details?.mediaInfo?.seasons ?? [] {
            statuses[season.seasonNumber] = season.status
        }
        for request in details?.mediaInfo?.requests ?? [] where request.status != .declined {
            for season in request.seasons ?? [] where (statuses[season.seasonNumber] ?? .unknown) == .unknown {
                statuses[season.seasonNumber] = .pending
            }
        }
        return statuses
    }

    var visibleSeasons: [SeerrSeason] {
        (details?.seasons ?? []).filter { $0.seasonNumber != 0 && $0.episodeCount != 0 }
    }

    var requestableSeasons: [SeerrSeason] {
        let statuses = seasonStatuses
        return visibleSeasons.filter { (statuses[$0.seasonNumber] ?? .unknown) == .unknown }
    }

    var selectedSeasons: [Int] {
        requestableSeasons.map(\.seasonNumber).filter { !deselectedSeasons.contains($0) }
    }

    var allSeasonsSelected: Bool {
        !requestableSeasons.isEmpty && selectedSeasons.count == requestableSeasons.count
    }

    var showsRequestButton: Bool {
        guard let details else { return false }
        return details.mediaType == .tv ? !requestableSeasons.isEmpty : details.status == .unknown
    }

    func toggleAllSeasons() {
        deselectedSeasons = allSeasonsSelected ? Set(requestableSeasons.map(\.seasonNumber)) : []
    }

    // MARK: - Actions

    func request() {
        guard let seerrStore, let details, !isRequesting else { return }
        let seasons = details.mediaType == .tv ? selectedSeasons : nil
        if details.mediaType == .tv, seasons?.isEmpty != false { return }

        isRequesting = true
        requestResult = nil
        Task {
            defer { isRequesting = false }
            do {
                try await seerrStore.perform {
                    try await $0.request(mediaType: details.mediaType, tmdbID: details.tmdbID, seasons: seasons)
                }
                requestResult = .success
                deselectedSeasons = []
                await loadDetails()
            } catch {
                requestResult = .failure
            }
        }
    }

    private func loadDetails() async {
        guard let seerrStore else { return }
        let route = route
        do {
            details = try await seerrStore.perform {
                try await $0.details(mediaType: route.mediaType, tmdbID: route.tmdbID)
            }
            loadFailed = false
        } catch {
            loadFailed = details == nil
        }
    }
}
