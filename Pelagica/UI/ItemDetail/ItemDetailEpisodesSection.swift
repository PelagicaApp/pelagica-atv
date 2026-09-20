//
//  ItemDetailEpisodesSection.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemDetailEpisodesSection: View {
    let seasons: [BaseItemDto]
    @Binding var selectedSeasonID: String?
    let episodes: [BaseItemDto]
    let seasonsNamespace: Namespace.ID
    let episodesNamespace: Namespace.ID
    let onPlayEpisode: (BaseItemDto) -> Void
    let onSelectSeason: (String) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Episodes")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 90)

            if seasons.count > 1 {
                seasonPicker
                    .focusScope(seasonsNamespace)
                    .focusSection()
            }

            episodesRow
                .focusScope(episodesNamespace)
                .focusSection()
        }
        .task(id: selectedSeasonID) {
            guard let selectedSeasonID else { return }
            await onSelectSeason(selectedSeasonID)
        }
    }

    private var seasonPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(seasons, id: \.id) { season in
                    Button {
                        selectedSeasonID = season.id
                    } label: {
                        Text(season.name ?? "Season")
                    }
                    .buttonStyle(SeasonPillButtonStyle(isSelected: season.id == selectedSeasonID))
                    .prefersDefaultFocus(season.id == seasons.first?.id, in: seasonsNamespace)
                }
            }
            .padding(.horizontal, 90)
        }
        .scrollClipDisabled()
    }

    private var episodesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 32) {
                ForEach(episodes, id: \.id) { episode in
                    EpisodeCard(
                        episode: episode,
                        isDefaultFocus: episode.id == episodes.first?.id,
                        focusNamespace: episodesNamespace,
                        onPlay: onPlayEpisode
                    )
                }
            }
            .padding(.horizontal, 90)
        }
        .scrollClipDisabled()
    }
}

private struct SeasonPillButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        SeasonPillBody(configuration: configuration, isSelected: isSelected)
    }

    private struct SeasonPillBody: View {
        let configuration: ButtonStyleConfiguration
        let isSelected: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(isSelected ? Color(white: 0.9) : Color.white.opacity(0.1)))
                .pelagicaFocusRing(isFocused: isFocused, cornerRadius: 100)
                .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1))
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }
}

private struct EpisodeCard: View {
    @EnvironmentObject private var appState: AppState
    let episode: BaseItemDto
    var isDefaultFocus = false
    var focusNamespace: Namespace.ID
    var onPlay: (BaseItemDto) -> Void

    private let cardWidth: CGFloat = 420
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                onPlay(episode)
            } label: {
                thumbnail
            }
            .buttonStyle(.card)
            .prefersDefaultFocus(isDefaultFocus, in: focusNamespace)

            Text(episodeTitle)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let overview = episode.overview, !overview.isEmpty {
                Text(overview)
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }

            metadataRow
        }
        .frame(width: cardWidth, alignment: .leading)
    }

    private var episodeTitle: String {
        let number = episode.indexNumber.map { "\($0). " } ?? ""
        return number + (episode.name ?? "Untitled")
    }

    private var thumbnailHeight: CGFloat { cardWidth * 9.0 / 16.0 }

    private var thumbnail: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.opacity(0.06)

            AsyncImage(url: imageURL) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && !isFailure(phase) ? 1 : 0)
                    fallbackIcon
                        .opacity(isFailure(phase) ? 1 : 0)
                    if let image = phase.image {
                        Color.clear.overlay {
                            image.resizable().scaledToFill()
                        }
                        .clipped()
                    }
                }
            }

            if let durationText {
                Text(durationText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7), in: Capsule())
                    .padding(10)
            }

            if let progress {
                VStack {
                    Spacer()
                    progressBar(progress)
                }
            }
        }
        .frame(width: cardWidth, height: thumbnailHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.4)

                Color.white
                    .frame(width: proxy.size.width * (progress / 100))
            }
        }
        .frame(height: 5)
    }

    private var progress: Double? {
        let watched: Int = episode.userData?.playbackPositionTicks ?? 0
        let runtime: Int = episode.runTimeTicks ?? 0
        let hasPlayed: Bool = episode.userData?.isPlayed ?? false
        return hasPlayed && watched <= 0
        ? 100.0
        : runtime > 0
        ? (Double(watched) / Double(runtime)) * 100.0
        : 0.0
    }

    private var metadataRow: some View {
        HStack(spacing: 12) {
            if let season = episode.parentIndexNumber, let number = episode.indexNumber {
                Text("S\(season) E\(number)")
            }

            if let rating = episode.communityRating {
                HStack(spacing: 4) {
                    Image(systemName: "star")
                    Text(String(format: "%.1f", rating))
                }
            }

            if let airDate = episode.premiereDate {
                Text(airDate.formatted(date: .long, time: .omitted))
            }
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.white.opacity(0.7))
    }

    private var durationText: String? {
        guard let ticks = episode.runTimeTicks else { return nil }
        let minutes = Int(Double(ticks) / 600_000_000)
        return "\(minutes)m"
    }

    private var fallbackIcon: some View {
        Image(systemName: "film")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.3))
    }

    private var imageURL: URL? {
        guard let id = episode.id, let client = appState.client else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(width: 840, height: 473, tag: episode.imageTags?["Primary"])
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}
