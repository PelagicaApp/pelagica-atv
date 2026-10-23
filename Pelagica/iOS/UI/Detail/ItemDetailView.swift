//
//  ItemDetailView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configStore: AppConfigStore
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var sizeClass

    @StateObject private var model: ItemDetailModel
    @State private var isOverviewExpanded = false

    init(item: BaseItemDto) {
        _model = StateObject(wrappedValue: ItemDetailModel(item: item))
    }

    private var item: BaseItemDto { model.item }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    actions
                    infoBlock
                }
                .padding(.horizontal)

                if item.type == .series, !model.seasons.isEmpty {
                    EpisodesSection(model: model)
                }

                if item.type == .boxSet, !model.boxSetItems.isEmpty {
                    Shelf(title: i18n.t("item:boxSetItems")) {
                        ForEach(model.boxSetItems, id: \.id) { item in
                            PosterCard(item: item)
                        }
                    }
                }

                if model.localTrailers.count > 1 {
                    Shelf(title: i18n.t("item:trailers")) {
                        ForEach(model.localTrailers, id: \.id) { trailer in
                            LandscapeCard(item: trailer) {
                                model.startPlayback(for: trailer)
                            }
                        }
                    }
                }

                if let people = item.people, !people.isEmpty {
                    Shelf(title: i18n.t("item:cast_and_crew")) {
                        ForEach(people, id: \.id) { person in
                            PersonCard(person: person)
                        }
                    }
                }

                ForEach(model.collectionItems.sorted(by: { $0.key < $1.key }), id: \.key) { name, items in
                    Shelf(title: name) {
                        ForEach(items, id: \.id) { item in
                            PosterCard(item: item)
                        }
                    }
                }

                if !model.similarItems.isEmpty {
                    Shelf(title: i18n.t("item:more_like_this")) {
                        ForEach(model.similarItems, id: \.id) { item in
                            PosterCard(item: item)
                        }
                    }
                }

                if !model.seerrRecommendations.isEmpty {
                    SeerrShelf(title: i18n.t("item:recommendations"), items: model.seerrRecommendations)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            model.bind(appState: appState, configStore: configStore, seerrStore: seerrStore)
            await model.load()
        }
        .onDisappear { model.stopThemeSong() }
        .playerCover($model.playbackTarget)
        .onChange(of: model.playbackTarget == nil) { wasNilBefore, isNilNow in
            guard isNilNow, !wasNilBefore else { return }
            Task { await model.playbackEnded() }
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .bottom) {
            RemoteImage(url: ItemImages.url(ItemImages.backdrop(item) ?? ItemImages.primary(item), client: appState.client, width: 1920, height: 1280))
                .aspectRatio(sizeClass == .regular ? 2.2 : 1, contentMode: .fit)
                .overlay {
                    LinearGradient(colors: [.black, .black.opacity(0.3), .clear], startPoint: .bottom, endPoint: .center)
                }

            VStack(spacing: 10) {
                titleBlock
                if !model.detailBadges.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(model.detailBadges.enumerated()), id: \.offset) { _, badge in
                            HStack(spacing: 4) {
                                if let icon = badge.icon {
                                    Image(systemName: icon == .star ? "star.fill" : "medal")
                                }
                                Text(badge.text)
                            }
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        if let logoURL = ItemImages.url(ItemImages.logo(item), client: appState.client, width: 800) {
            AsyncImage(url: logoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    titleText
                }
            }
            .frame(maxWidth: 280, maxHeight: 100)
        } else {
            titleText
        }
    }

    private var titleText: some View {
        Text(item.name ?? i18n.t("no_title"))
            .font(.largeTitle.weight(.bold))
            .multilineTextAlignment(.center)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: model.play) {
                Label(model.playLabel, systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.large)

            HStack(spacing: 12) {
                if model.trailerAvailable {
                    actionButton(i18n.t("item:trailer"), systemImage: "film", action: playTrailer)
                }
                if model.showsWatchlistButton {
                    actionButton(
                        model.isWatchlist ? i18n.t("item:remove_from_watchlist") : i18n.t("item:add_to_watchlist"),
                        systemImage: model.isWatchlist ? "bookmark.fill" : "bookmark",
                        action: model.toggleWatchlist
                    )
                    .disabled(model.isTogglingWatchlist)
                }
                if model.showsFavoriteButton {
                    actionButton(
                        model.isFavorite ? i18n.t("item:unfavorite") : i18n.t("item:favorite"),
                        systemImage: model.isFavorite ? "heart.fill" : "heart",
                        action: model.toggleFavorite
                    )
                    .disabled(model.isTogglingFavorite)
                }
                if model.showsPlayedButton {
                    actionButton(
                        model.isPlayed ? i18n.t("item:mark_as_unplayed") : i18n.t("item:mark_as_played"),
                        systemImage: model.isPlayed ? "checkmark.circle.fill" : "checkmark.circle",
                        action: model.toggleItemPlayed
                    )
                    .disabled(model.isTogglingPlayed)
                }
                if let seerrRoute = model.seerrRoute {
                    NavigationLink(value: seerrRoute) {
                        actionLabel(i18n.t("seerr:seerr_button_label"), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(height: 24)
            Text(title)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func playTrailer() {
        if let trailerURL = model.playTrailer() {
            openURL(trailerURL)
        }
    }

    // MARK: Info

    @ViewBuilder
    private var infoBlock: some View {
        if let genres = item.genres, !genres.isEmpty {
            Text(genres.joined(separator: " ⋅ "))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if let overview = item.overview, !overview.isEmpty {
            Text(overview)
                .font(.callout)
                .lineLimit(isOverviewExpanded ? nil : 4)
                .onTapGesture { withAnimation { isOverviewExpanded.toggle() } }
        }
    }
}

private struct EpisodesSection: View {
    @ObservedObject var model: ItemDetailModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(i18n.t("item:episodes"))
                    .font(.title3.weight(.bold))
                Spacer()
                if model.seasons.count > 1 {
                    Picker(i18n.t("settings:season"), selection: $model.selectedSeasonID) {
                        ForEach(model.seasons, id: \.id) { season in
                            Text(season.name ?? i18n.t("settings:season")).tag(season.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.horizontal)

            LazyVStack(spacing: 14) {
                ForEach(model.episodes, id: \.id) { episode in
                    EpisodeRow(episode: episode, model: model)
                }
            }
            .padding(.horizontal)
        }
        .task(id: model.selectedSeasonID) {
            guard let seasonID = model.selectedSeasonID else { return }
            await model.loadEpisodes(seasonID: seasonID)
        }
    }
}

private struct EpisodeRow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    let episode: BaseItemDto
    let model: ItemDetailModel

    var body: some View {
        Button {
            model.startPlayback(for: episode)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    RemoteImage(url: ItemImages.url(ItemImages.landscape(episode), client: appState.client, width: 480, height: 270))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(width: 140 * CardMetrics.landscapeScale(sizeClass))
                        .overlay(alignment: .bottom) {
                            if let progress = episode.playbackProgress {
                                ProgressView(value: progress).tint(.white).padding(6)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text((episode.indexNumber.map { "\($0). " } ?? "") + (episode.name ?? i18n.t("no_title")))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        if let runtime = episode.runTimeTicks {
                            Text("\(runtime / 600_000_000) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    if episode.userData?.isPlayed == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                model.togglePlayed(episode)
            } label: {
                if episode.userData?.isPlayed == true {
                    Label(i18n.t("item:mark_as_unplayed"), systemImage: "circle")
                } else {
                    Label(i18n.t("item:mark_as_played"), systemImage: "checkmark.circle")
                }
            }
        }
    }
}

private struct PersonCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    let person: BaseItemPerson

    var body: some View {
        NavigationLink(value: person.id.map { PersonDetailRoute(id: $0, name: person.name) }) {
            VStack(spacing: 6) {
                RemoteImage(url: imageURL, fallbackSymbol: "person")
                    .frame(width: 84 * CardMetrics.scale(sizeClass), height: 84 * CardMetrics.scale(sizeClass))
                    .clipShape(Circle())

                VStack(spacing: 2) {
                    Text(person.name ?? i18n.t("item:unknown_item"))
                        .font(.caption.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
            .frame(width: 92 * CardMetrics.scale(sizeClass))
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String? {
        if let role = person.role, !role.isEmpty { return role }
        return person.type?.rawValue
    }

    private var imageURL: URL? {
        guard let id = person.id else { return nil }
        return ItemImages.url(ItemImages.Source(itemID: id, type: .primary, tag: person.primaryImageTag), client: appState.client, width: 250, height: 250)
    }
}
