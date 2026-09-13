//
//  ItemDetailHeroSection.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemDetailHeroSection: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configStore: AppConfigStore

    let item: BaseItemDto
    let isWatchlist: Bool
    let isTogglingWatchlist: Bool
    let trailerAvailable: Bool
    let playLabel: String
    let namespace: Namespace.ID
    var isPlayButtonFocused: FocusState<Bool>.Binding
    let onPlay: () -> Void
    let onPlayTrailer: () -> Void
    let onToggleWatchlist: () -> Void

    var body: some View {
        ZStack(alignment: .center) {
            ZStack {
                backdrop
                scrim
            }
            .ignoresSafeArea(edges: [.top, .horizontal])

            HStack(alignment: .top, spacing: 60) {
                poster

                VStack(alignment: .leading, spacing: 24) {
                    titleBlock
                    detailBadgesRow
                    genresText
                    overviewText
                    buttonsRow
                }

                Spacer()
            }
            .padding(.top, 120)
            .padding(.horizontal, 90)
        }
        .clipped()
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

    // MARK: - Poster

    private var poster: some View {
        ZStack {
            Color.white.opacity(0.06)

            AsyncImage(url: posterURL) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && !isFailure(phase) ? 1 : 0)
                    fallbackIcon
                        .opacity(isFailure(phase) ? 1 : 0)
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

    private var fallbackIcon: some View {
        Image(systemName: "film")
            .font(.system(size: 48))
            .foregroundStyle(.white.opacity(0.3))
    }

    // MARK: - Title

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

    private var titleText: some View {
        Text(item.name ?? "Untitled")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.white)
    }

    // MARK: - Detail Badges

    private var detailBadgesRow: some View {
        let types = configStore.config.itemPage?.detailBadges ?? DetailBadges.defaultBadges
        let badges = types.compactMap { DetailBadges.value(for: item, type: $0) }

        return Group {
            if !badges.isEmpty {
                HStack(spacing: 20) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                        detailBadge(badge)
                    }
                }
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
            }
        }
    }

    private func detailBadge(_ badge: DetailBadgeValue) -> some View {
        HStack(spacing: 6) {
            if let icon = badge.icon {
                Image(systemName: icon == .star ? "star" : "medal")
            }
            Text(badge.text)
        }
        
    }

    @ViewBuilder
    private var genresText: some View {
        if let genres = item.genres, !genres.isEmpty {
            Text(genres.joined(separator: " ⋅ "))
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var overviewText: some View {
        if let overview = item.overview, !overview.isEmpty {
            Text(overview)
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .lineLimit(3)
        }
    }

    // MARK: - Actions

    private var buttonsRow: some View {
        HStack(spacing: 20) {
            Button(action: onPlay) {
                Label(playLabel, systemImage: "play.fill")
            }
            .buttonStyle(DetailActionButtonStyle(emphasis: .primary))
            .prefersDefaultFocus(true, in: namespace)
            .focused(isPlayButtonFocused)

            if trailerAvailable {
                Button(action: onPlayTrailer) {
                    Label("Trailer", systemImage: "film")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
            }

            Button(action: onToggleWatchlist) {
                Label(isWatchlist ? "In Watchlist" : "Add to Watchlist", systemImage: isWatchlist ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
            .disabled(isTogglingWatchlist)
        }
        .padding(.top, 10)
    }

    // MARK: - Images

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }

    private var posterURL: URL? {
        guard let id = item.id, let client = appState.client else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(fillWidth: 640, fillHeight: 960, tag: item.imageTags?["Primary"])
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private var backdropURL: URL? {
        guard let id = item.id, let client = appState.client, let tag = item.backdropImageTags?.first else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.backdrop.rawValue,
            parameters: .init(fillWidth: 1920, fillHeight: 1080, tag: tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private var logoURL: URL? {
        guard let id = item.id, let client = appState.client, let tag = item.imageTags?["Logo"] else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.logo.rawValue,
            parameters: .init(fillWidth: 800, tag: tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }
}

struct DetailActionButtonStyle: ButtonStyle {
    var emphasis: PelagicaButtonEmphasis

    func makeBody(configuration: Configuration) -> some View {
        DetailActionButtonBody(configuration: configuration, emphasis: emphasis)
    }

    private struct DetailActionButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let emphasis: PelagicaButtonEmphasis
        @Environment(\.isFocused) private var isFocused

        private let cornerRadius: CGFloat = 16

        var body: some View {
            configuration.label
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(emphasis == .primary ? .black : .white)
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(emphasis == .primary ? Color(white: 0.9) : Color.white.opacity(0.12))
                )
                .pelagicaFocusRing(isFocused: isFocused, cornerRadius: cornerRadius)
                .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.03 : 1))
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }
}
