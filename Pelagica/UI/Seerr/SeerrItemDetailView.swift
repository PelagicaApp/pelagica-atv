//
//  SeerrItemDetailView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct SeerrItemDetailView: View {
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.openURL) private var openURL

    let route: SeerrItemRoute

    @State private var details: SeerrDetails?
    @State private var loadFailed = false
    @State private var recommendations: [SeerrMediaItem] = []
    @State private var deselectedSeasons: Set<Int> = []
    @State private var isRequesting = false
    @State private var requestResult: RequestResult?

    @Namespace private var heroNamespace

    private enum RequestResult {
        case success
        case failure
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 60) {
                    hero
                        .frame(height: proxy.size.height * 0.87)
                        .focusScope(heroNamespace)
                        .focusSection()

                    if details?.mediaType == .tv, !visibleSeasons.isEmpty {
                        seasonsSection
                    }

                    if !recommendations.isEmpty {
                        SeerrItemsRow(title: i18n.t("item:recommendations"), items: recommendations)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .background(PelagicaBackground())
        .task {
            await loadDetails()
            recommendations = await seerrStore.items {
                try await $0.recommendations(mediaType: route.mediaType, tmdbID: route.tmdbID)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            ZStack {
                AsyncImage(url: SeerrImage.backdrop(details?.backdropPath)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
                LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .bottom, endPoint: .top)
                LinearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
            }
            .ignoresSafeArea(edges: [.top, .horizontal])

            HStack(alignment: .top, spacing: 60) {
                poster

                VStack(alignment: .leading, spacing: 24) {
                    Text(details?.title ?? route.title ?? "")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let details {
                        badgesRow(details)

                        if !details.genres.isEmpty {
                            Text(details.genres.joined(separator: " ⋅ "))
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        if let overview = details.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .lineLimit(4)
                        }

                        buttonsRow(details)

                        if let requestResult {
                            Text(requestResult == .success ? i18n.t("seerr:seerr_request_success") : i18n.t("seerr:seerr_request_failed"))
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(requestResult == .success ? .green : .red)
                        }
                    } else if loadFailed {
                        Text(i18n.t("seerr:seerr_failed_to_load"))
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }

                Spacer()
            }
            .padding(.top, 120)
            .padding(.horizontal, 90)
        }
        .clipped()
    }

    private var poster: some View {
        ZStack {
            Color.white.opacity(0.06)

            AsyncImage(url: SeerrImage.poster(details?.posterPath)) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && details == nil ? 1 : 0)
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(phase.image == nil && details != nil ? 1 : 0)
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: 400, height: 600)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.85), radius: 40, y: 25)
    }

    private func badgesRow(_ details: SeerrDetails) -> some View {
        HStack(spacing: 20) {
            if let year = details.releaseYear {
                Text(year)
            }
            Text(details.mediaType == .movie ? i18n.t("seerr:seerr_movie") : i18n.t("seerr:seerr_tv_show"))
            SeerrStatusBadge(status: details.status)
        }
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(.white)
    }

    private func buttonsRow(_ details: SeerrDetails) -> some View {
        FlowLayout(horizontalSpacing: 20, verticalSpacing: 20) {
            if showsRequestButton {
                Button(action: request) {
                    Label(requestLabel, systemImage: "arrow.down.circle")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .primary))
                .disabled(isRequesting || (details.mediaType == .tv && selectedSeasons.isEmpty))
                .prefersDefaultFocus(true, in: heroNamespace)
            }

            if let libraryRoute {
                NavigationLink(value: libraryRoute) {
                    Label(i18n.t("seerr:seerr_open_in_library"), systemImage: "play.fill")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: showsRequestButton ? .secondary : .primary))
                .prefersDefaultFocus(!showsRequestButton, in: heroNamespace)
            }

            if let trailerURL = details.trailerURL {
                Button {
                    openURL(trailerURL)
                } label: {
                    Label(i18n.t("seerr:seerr_watch_trailer"), systemImage: "film")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
            }
        }
        .padding(.top, 10)
    }

    private var requestLabel: String {
        if isRequesting { return i18n.t("seerr:seerr_requesting") }
        if details?.mediaType == .tv, !selectedSeasons.isEmpty {
            return i18n.t("seerr:seerr_request_seasons_count", count: selectedSeasons.count)
        }
        return i18n.t("seerr:seerr_request")
    }

    private var libraryRoute: ItemDetailRoute? {
        guard let details, let jellyfinID = details.mediaInfo?.jellyfinMediaId,
              details.status == .available || details.status == .partiallyAvailable else { return nil }
        return ItemDetailRoute(item: BaseItemDto(id: jellyfinID, name: details.title))
    }

    // MARK: - Seasons

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 30) {
                Text(i18n.t("seerr:seerr_select_seasons"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if !requestableSeasons.isEmpty {
                    Button(action: toggleAllSeasons) {
                        Text(allSeasonsSelected ? i18n.t("seerr:seerr_deselect_all") : i18n.t("seerr:seerr_select_all"))
                    }
                    .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                }
            }

            VStack(spacing: 16) {
                ForEach(visibleSeasons, id: \.seasonNumber) { season in
                    seasonRow(season)
                }
            }
        }
        .padding(.horizontal, 90)
        .focusSection()
    }

    private func seasonRow(_ season: SeerrSeason) -> some View {
        let isRequestable = requestableSeasons.contains(season)
        let isSelected = selectedSeasons.contains(season.seasonNumber)

        return Button {
            guard isRequestable else { return }
            if isSelected {
                deselectedSeasons.insert(season.seasonNumber)
            } else {
                deselectedSeasons.remove(season.seasonNumber)
            }
        } label: {
            HStack(spacing: 24) {
                Image(systemName: isRequestable ? (isSelected ? "checkmark.square.fill" : "square") : "square.dashed")
                    .font(.system(size: 30))
                    .foregroundStyle(isRequestable ? .white : .white.opacity(0.3))
                    .frame(width: 40)

                Text(i18n.t("seerr:seerr_season_number", ["number": season.seasonNumber]))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)

                if let episodeCount = season.episodeCount {
                    Text(i18n.t("episode_count", count: episodeCount))
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SeerrStatusBadge(status: seasonStatuses[season.seasonNumber] ?? .unknown)
            }
        }
        .buttonStyle(SeasonRowButtonStyle())
    }

    /// Season availability, with seasons that have an open request counted as pending.
    private var seasonStatuses: [Int: SeerrMediaStatus] {
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

    private var visibleSeasons: [SeerrSeason] {
        (details?.seasons ?? []).filter { $0.seasonNumber != 0 && $0.episodeCount != 0 }
    }

    private var requestableSeasons: [SeerrSeason] {
        let statuses = seasonStatuses
        return visibleSeasons.filter { (statuses[$0.seasonNumber] ?? .unknown) == .unknown }
    }

    private var selectedSeasons: [Int] {
        requestableSeasons.map(\.seasonNumber).filter { !deselectedSeasons.contains($0) }
    }

    private var allSeasonsSelected: Bool {
        !requestableSeasons.isEmpty && selectedSeasons.count == requestableSeasons.count
    }

    private var showsRequestButton: Bool {
        guard let details else { return false }
        return details.mediaType == .tv ? !requestableSeasons.isEmpty : details.status == .unknown
    }

    private func toggleAllSeasons() {
        deselectedSeasons = allSeasonsSelected ? Set(requestableSeasons.map(\.seasonNumber)) : []
    }

    // MARK: - Actions

    private func request() {
        guard let details, !isRequesting else { return }
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

private struct SeasonRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SeasonRowBody(configuration: configuration)
    }

    private struct SeasonRowBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        private let cornerRadius: CGFloat = 16

        var body: some View {
            configuration.label
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(isFocused ? 0.12 : 0.06))
                )
                .pelagicaFocusRing(isFocused: isFocused, cornerRadius: cornerRadius)
                .scaleEffect(configuration.isPressed ? 0.99 : 1)
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }
}
