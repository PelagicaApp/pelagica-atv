//
//  SeerrItemDetailView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct SeerrItemDetailView: View {
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.openURL) private var openURL

    @StateObject private var model: SeerrItemDetailModel

    init(route: SeerrItemRoute) {
        _model = StateObject(wrappedValue: SeerrItemDetailModel(route: route))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let details = model.details {
                    VStack(alignment: .leading, spacing: 16) {
                        actions(details)

                        if let requestResult = model.requestResult {
                            Text(requestResult == .success ? i18n.t("seerr:seerr_request_success") : i18n.t("seerr:seerr_request_failed"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(requestResult == .success ? .green : .red)
                        }

                        if !details.genres.isEmpty {
                            Text(details.genres.joined(separator: " ⋅ "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let overview = details.overview, !overview.isEmpty {
                            Text(overview).font(.callout)
                        }
                    }
                    .padding(.horizontal)

                    if details.mediaType == .tv, !model.visibleSeasons.isEmpty {
                        seasonsSection
                    }
                } else if model.loadFailed {
                    ContentUnavailableView(i18n.t("seerr:seerr_failed_to_load"), systemImage: "exclamationmark.triangle")
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }

                if !model.recommendations.isEmpty {
                    SeerrShelf(title: i18n.t("item:recommendations"), items: model.recommendations)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            model.bind(seerrStore: seerrStore)
            await model.load()
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: SeerrImage.backdrop(model.details?.backdropPath))
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay {
                    LinearGradient(colors: [.black, .black.opacity(0.3), .clear], startPoint: .bottom, endPoint: .center)
                }

            HStack(alignment: .bottom, spacing: 14) {
                RemoteImage(url: SeerrImage.poster(model.details?.posterPath))
                    .frame(width: 96, height: 144)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.details?.title ?? model.route.title ?? "")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)

                    if let details = model.details {
                        HStack(spacing: 8) {
                            if let year = details.releaseYear { Text(year) }
                            Text(details.mediaType == .movie ? i18n.t("seerr:seerr_movie") : i18n.t("seerr:seerr_tv_show"))
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        SeerrStatusBadge(status: details.status)
                    }
                }
            }
            .padding(.horizontal)
            .offset(y: 40)
        }
        .padding(.bottom, 40)
    }

    private func actions(_ details: SeerrDetails) -> some View {
        VStack(spacing: 10) {
            if model.showsRequestButton {
                Button(action: model.request) {
                    HStack {
                        if model.isRequesting { ProgressView().tint(.black) } else { Image(systemName: "arrow.down.circle") }
                        Text(model.requestLabel)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .controlSize(.large)
                .disabled(model.isRequesting || (details.mediaType == .tv && model.selectedSeasons.isEmpty))
            }

            HStack(spacing: 10) {
                if let libraryRoute = model.libraryRoute {
                    NavigationLink(value: libraryRoute) {
                        Label(i18n.t("seerr:seerr_open_in_library"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let trailerURL = details.trailerURL {
                    Button {
                        openURL(trailerURL)
                    } label: {
                        Label(i18n.t("seerr:seerr_watch_trailer"), systemImage: "film")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)
        }
    }

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(i18n.t("seerr:seerr_select_seasons"))
                    .font(.title3.weight(.bold))
                Spacer()
                if !model.requestableSeasons.isEmpty {
                    Button(model.allSeasonsSelected ? i18n.t("seerr:seerr_deselect_all") : i18n.t("seerr:seerr_select_all")) {
                        model.toggleAllSeasons()
                    }
                    .font(.subheadline)
                }
            }

            ForEach(model.visibleSeasons, id: \.seasonNumber) { season in
                seasonRow(season)
                if season.seasonNumber != model.visibleSeasons.last?.seasonNumber {
                    Divider()
                }
            }
        }
        .padding(.horizontal)
    }

    private func seasonRow(_ season: SeerrSeason) -> some View {
        let isRequestable = model.requestableSeasons.contains(season)
        let isSelected = model.selectedSeasons.contains(season.seasonNumber)

        return Button {
            model.toggleSeason(season)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isRequestable ? (isSelected ? "checkmark.circle.fill" : "circle") : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(isRequestable ? .primary : .tertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("seerr:seerr_season_number", ["number": season.seasonNumber]))
                        .font(.subheadline.weight(.semibold))
                    if let episodeCount = season.episodeCount {
                        Text(i18n.t("episode_count", count: episodeCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                SeerrStatusBadge(status: model.seasonStatuses[season.seasonNumber] ?? .unknown)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isRequestable)
    }
}
