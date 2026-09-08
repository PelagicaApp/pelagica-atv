//
//  HomeMediaBar.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct HomeMediaBar: View {
    @EnvironmentObject private var appState: AppState

    let items: [BaseItemDto]
    let showFavoriteButton: Bool
    let showWatchlistButton: Bool
    var onButtonFocused: () -> Void = {}

    @State private var index = 0
    @State private var nextEpisode: BaseItemDto?
    @State private var isFavorite = false
    @State private var isWatchlist = false
    @State private var isTogglingFavorite = false
    @State private var isTogglingWatchlist = false

    private enum FocusableButton: Hashable {
        case play, favorite, watchlist, next
    }

    @Namespace private var namespace
    @FocusState private var focusedButton: FocusableButton?

    private var currentItem: BaseItemDto? {
        items.indices.contains(index) ? items[index] : nil
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
                .id(currentItem?.id)
                .ignoresSafeArea(edges: [.top, .horizontal])

            scrim
                .ignoresSafeArea(edges: [.top, .horizontal])

            VStack(alignment: .leading, spacing: 24) {
                titleBlock
                metadataRow
                genresText
                overviewText
                buttonsRow
            }
            .id(currentItem?.id)
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, 90)
            .padding(.bottom, 90)
        }
        .clipped()
        .task(id: currentItem?.id) {
            syncUserDataState()
            await loadNextEpisode()
        }
        .onChange(of: focusedButton) { _, newValue in
            if newValue != nil { onButtonFocused() }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        AsyncImage(url: backdropURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            }
        }
    }

    private var scrim: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.95), .black.opacity(0.6), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            LinearGradient(
                colors: [.black.opacity(0.85), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    // MARK: - Text

    private var titleText: some View {
        Text(currentItem?.name ?? "")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(height: 140, alignment: .bottomLeading)
    }
    
    @ViewBuilder
    private var titleBlock: some View {
        if let logoURL {
            AsyncImage(url: logoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    titleText
                }
            }
            .frame(maxWidth: 560, maxHeight: 150, alignment: .leading)
        } else {
            titleText
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 20) {
            if let year = currentItem?.productionYear {
                Text(year, format: .number.grouping(.never))
            }

            if let rating = currentItem?.communityRating {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                    Text(String(format: "%.1f", rating))
                }
            }

            if let durationText {
                Text(durationText)
            }

            if let officialRating = currentItem?.officialRating {
                Text(officialRating)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
            }
        }
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(.white)
    }

    private var durationText: String? {
        if currentItem?.type == .series {
            let seasonCount = currentItem?.childCount ?? 1
            return seasonCount == 1 ? "1 Season" : "\(seasonCount) Seasons"
        }

        guard let ticks = currentItem?.runTimeTicks else { return nil }
        let totalMinutes = Int(Double(ticks) / 600_000_000)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var genresText: some View {
        Text(currentItem?.genres?.joined(separator: " ⋅ ") ?? "")
            .font(.system(size: 22))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(height: 34, alignment: .leading)
    }

    private var overviewText: some View {
        Text(currentItem?.overview ?? "")
            .font(.system(size: 22))
            .foregroundStyle(.white)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(height: 96, alignment: .topLeading)
    }

    // MARK: - Actions

    private var buttonsRow: some View {
        HStack(spacing: 20) {
            NavigationLink(value: currentItem.map { ItemDetailRoute(item: $0) }) {
                Label("Watch now", systemImage: "play.fill")
            }
            .buttonStyle(DetailActionButtonStyle(emphasis: .primary))
            .prefersDefaultFocus(true, in: namespace)
            .focused($focusedButton, equals: .play)

            if showFavoriteButton {
                Button(action: toggleFavorite) {
                    Label(isFavorite ? "Favorited" : "Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                .disabled(isTogglingFavorite)
                .focused($focusedButton, equals: .favorite)
            }

            if showWatchlistButton {
                Button(action: toggleWatchlist) {
                    Label(isWatchlist ? "In Watchlist" : "Add to Watchlist", systemImage: isWatchlist ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                .disabled(isTogglingWatchlist)
                .focused($focusedButton, equals: .watchlist)
            }

            if items.count > 1 {
                Button(action: advance) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                .focused($focusedButton, equals: .next)
            }
        }
        .focusScope(namespace)
    }

    private func advance() {
        guard !items.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            index = (index + 1) % items.count
        }
    }

    private func syncUserDataState() {
        isFavorite = currentItem?.userData?.isFavorite ?? false
        isWatchlist = currentItem?.userData?.isLikes ?? false
    }

    private func toggleFavorite() {
        guard let client = appState.client, let id = currentItem?.id, !isTogglingFavorite else { return }
        let newValue = !isFavorite
        isFavorite = newValue
        isTogglingFavorite = true

        Task {
            defer { isTogglingFavorite = false }
            do {
                _ = try await client.send(Paths.updateItemUserData(
                    itemID: id,
                    userID: appState.currentUser?.id,
                    UpdateUserItemDataDto(isFavorite: newValue)
                ))
            } catch {
                isFavorite = !newValue
            }
        }
    }

    private func toggleWatchlist() {
        guard let client = appState.client, let id = currentItem?.id, !isTogglingWatchlist else { return }
        let newValue = !isWatchlist
        isWatchlist = newValue
        isTogglingWatchlist = true

        Task {
            defer { isTogglingWatchlist = false }
            do {
                _ = try await client.send(Paths.updateItemUserData(
                    itemID: id,
                    userID: appState.currentUser?.id,
                    UpdateUserItemDataDto(isLikes: newValue)
                ))
            } catch {
                isWatchlist = !newValue
            }
        }
    }

    // MARK: - Data loading

    private func loadNextEpisode() async {
        nextEpisode = nil
        guard let client = appState.client, currentItem?.type == .series, let seriesID = currentItem?.id else { return }
        do {
            let nextUp = try await client.send(Paths.getNextUp(parameters: .init(
                userID: appState.currentUser?.id,
                limit: 1,
                seriesID: seriesID
            ))).value
            if let episode = nextUp.items?.first {
                nextEpisode = episode
                return
            }

            let episodes = try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: .init(
                userID: appState.currentUser?.id,
                limit: 1
            ))).value
            nextEpisode = episodes.items?.first
        } catch {
            // The Play button just falls back to a generic label.
        }
    }

    // MARK: - Images

    private var backdropURL: URL? {
        guard let currentItem, let id = currentItem.id, let client = appState.client, let tag = currentItem.backdropImageTags?.first else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.backdrop.rawValue,
            parameters: .init(fillWidth: 1920, fillHeight: 1080, tag: tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }
    
    private var logoURL: URL? {
        guard let currentItem, let id = currentItem.id, let client = appState.client, let tag = currentItem.imageTags?["Logo"] else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.logo.rawValue,
            parameters: .init(fillWidth: 800, tag: tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HomeMediaBar(
            items: [BaseItemDto(name: "Preview Item", overview: "A short preview overview.")],
            showFavoriteButton: true,
            showWatchlistButton: true
        )
    }
    .environmentObject(AppState())
}
