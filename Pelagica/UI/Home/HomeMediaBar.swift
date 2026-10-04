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

    /// How long each item stays on screen before going to the next one. Zoom is over that duration
    private static let slideDuration: Double = 25
    private static let backdropZoom: CGFloat = 1.08

    @Environment(\.scenePhase) private var scenePhase
    @State private var index = 0
    @State private var nextEpisode: BaseItemDto?
    @State private var isFavorite = false
    @State private var isWatchlist = false
    @State private var isTogglingFavorite = false
    @State private var isTogglingWatchlist = false
    @State private var isScrolledIntoView = true
    @State private var isOnScreen = false

    private enum FocusableButton: Hashable {
        case play, favorite, watchlist, next
    }

    @Namespace private var namespace
    @FocusState private var focusedButton: FocusableButton?

    private var currentItem: BaseItemDto? {
        items.indices.contains(index) ? items[index] : nil
    }

    private var shouldAutoAdvance: Bool {
        items.count > 1 && isOnScreen && isScrolledIntoView && scenePhase == .active
    }

    private struct AutoAdvanceKey: Equatable {
        let itemID: String?
        let isActive: Bool
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
        .frame(height: 1100)
        .clipped()
        .task(id: currentItem?.id) {
            syncUserDataState()
            await loadNextEpisode()
        }
        .task(id: AutoAdvanceKey(itemID: currentItem?.id, isActive: shouldAutoAdvance)) {
            guard shouldAutoAdvance else { return }
            try? await Task.sleep(for: .seconds(Self.slideDuration))
            guard !Task.isCancelled else { return }
            advance()
        }
        .onScrollVisibilityChange(threshold: 0.5) { isScrolledIntoView = $0 }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .onChange(of: focusedButton) { _, newValue in
            if newValue != nil { onButtonFocused() }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        AsyncImage(url: backdropURL) { phase in
            if let image = phase.image {
                SlowZoomImage(image: image, zoom: Self.backdropZoom, duration: Self.slideDuration)
            }
        }
    }

    private var scrim: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .black.opacity(0.6), .clear],
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
            return i18n.t("season_count", count: seasonCount)
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
            .foregroundStyle(.white.opacity(0.6))
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
                Label(i18n.t("home:play"), systemImage: "play.fill")
            }
            .buttonStyle(DetailActionButtonStyle(emphasis: .primary))
            .prefersDefaultFocus(true, in: namespace)
            .focused($focusedButton, equals: .play)

            if showFavoriteButton {
                Button(action: toggleFavorite) {
                    Label(isFavorite ? i18n.t("item:unfavorite") : i18n.t("item:favorite"), systemImage: isFavorite ? "heart.fill" : "heart")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                .disabled(isTogglingFavorite)
                .focused($focusedButton, equals: .favorite)
            }

            if showWatchlistButton {
                Button(action: toggleWatchlist) {
                    Label(isWatchlist ? i18n.t("item:remove_from_watchlist") : i18n.t("item:add_to_watchlist"), systemImage: isWatchlist ? "bookmark.fill" : "bookmark")
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

private struct SlowZoomImage: View {
    let image: Image
    let zoom: CGFloat
    let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isZoomed = false

    var body: some View {
        image
            .resizable()
            .scaledToFill()
            .scaleEffect(isZoomed && !reduceMotion ? zoom : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: duration)) {
                    isZoomed = true
                }
            }
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
