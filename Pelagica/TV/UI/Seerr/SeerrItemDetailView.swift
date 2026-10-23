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

    @Namespace private var heroNamespace

    init(route: SeerrItemRoute) {
        _model = StateObject(wrappedValue: SeerrItemDetailModel(route: route))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 60) {
                    hero
                        .frame(height: proxy.size.height * 0.87)
                        .focusScope(heroNamespace)
                        .focusSection()

                    if model.details?.mediaType == .tv, !model.visibleSeasons.isEmpty {
                        seasonsSection
                    }

                    if !model.recommendations.isEmpty {
                        SeerrItemsRow(title: i18n.t("item:recommendations"), items: model.recommendations)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .background(PelagicaBackground())
        .task {
            model.bind(seerrStore: seerrStore)
            await model.load()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            ZStack {
                AsyncImage(url: SeerrImage.backdrop(model.details?.backdropPath)) { phase in
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
                    Text(model.details?.title ?? model.route.title ?? "")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let details = model.details {
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

                        if let requestResult = model.requestResult {
                            Text(requestResult == .success ? i18n.t("seerr:seerr_request_success") : i18n.t("seerr:seerr_request_failed"))
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(requestResult == .success ? .green : .red)
                        }
                    } else if model.loadFailed {
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

            AsyncImage(url: SeerrImage.poster(model.details?.posterPath)) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && model.details == nil ? 1 : 0)
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(phase.image == nil && model.details != nil ? 1 : 0)
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
            if model.showsRequestButton {
                Button(action: model.request) {
                    Label {
                        Text(model.requestLabel)
                    } icon: {
                        if model.isRequesting {
                            ProgressView()
                                .tint(.white.opacity(0.6))
                                .scaleEffect(0.6)
                                .frame(width: 26, height: 26)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                    }
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .primary))
                .disabled(model.isRequesting || (details.mediaType == .tv && model.selectedSeasons.isEmpty))
                .prefersDefaultFocus(true, in: heroNamespace)
            }

            if let libraryRoute = model.libraryRoute {
                NavigationLink(value: libraryRoute) {
                    Label(i18n.t("seerr:seerr_open_in_library"), systemImage: "play.fill")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: model.showsRequestButton ? .secondary : .primary))
                .prefersDefaultFocus(!model.showsRequestButton, in: heroNamespace)
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

    // MARK: - Seasons

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 30) {
                Text(i18n.t("seerr:seerr_select_seasons"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if !model.requestableSeasons.isEmpty {
                    Button(action: model.toggleAllSeasons) {
                        Text(model.allSeasonsSelected ? i18n.t("seerr:seerr_deselect_all") : i18n.t("seerr:seerr_select_all"))
                    }
                    .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                }
            }

            VStack(spacing: 16) {
                ForEach(model.visibleSeasons, id: \.seasonNumber) { season in
                    seasonRow(season)
                }
            }
        }
        .padding(.horizontal, 90)
        .focusSection()
    }

    private func seasonRow(_ season: SeerrSeason) -> some View {
        let isRequestable = model.requestableSeasons.contains(season)
        let isSelected = model.selectedSeasons.contains(season.seasonNumber)

        return Button {
            model.toggleSeason(season)
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

                SeerrStatusBadge(status: model.seasonStatuses[season.seasonNumber] ?? .unknown)
            }
        }
        .buttonStyle(SeasonRowButtonStyle())
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
