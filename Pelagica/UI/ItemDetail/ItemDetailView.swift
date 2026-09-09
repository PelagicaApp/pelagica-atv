//
//  ItemDetailView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct ItemDetailRoute: Hashable {
    let item: BaseItemDto
}

struct PlaybackTarget: Identifiable {
    let id = UUID()
    let item: BaseItemDto
    let startTicks: Int
}

struct ItemDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL

    @State private var item: BaseItemDto
    @State private var nextEpisode: BaseItemDto?
    @State private var isWatchlist: Bool
    @State private var isTogglingWatchlist = false

    @State private var seasons: [BaseItemDto] = []
    @State private var selectedSeasonID: String?
    @State private var episodes: [BaseItemDto] = []

    @State private var playbackTarget: PlaybackTarget?
    @State private var localTrailer: BaseItemDto?

    @Namespace private var heroNamespace
    @Namespace private var seasonsNamespace
    @Namespace private var episodesNamespace
    @FocusState private var isPlayButtonFocused: Bool

    init(item: BaseItemDto) {
        _item = State(initialValue: item)
        _isWatchlist = State(initialValue: item.userData?.isLikes ?? false)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 60) {
                    hero
                        .frame(height: proxy.size.height)
                        .focusScope(heroNamespace)
                        .focusSection()

                    if item.type == .series {
                        episodesSection
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .task {
            await loadFullItem()
            await loadLocalTrailer()
            if item.type == .series {
                await loadNextEpisode()
                await loadSeasons()
            }
        }
        .fullScreenCover(item: $playbackTarget) { target in
            VideoPlayerView(item: target.item, startTicks: target.startTicks)
                .ignoresSafeArea()
        }
        .onChange(of: playbackTarget == nil) { wasNilBefore, isNilNow in
            guard isNilNow, !wasNilBefore else { return }
            Task {
                await loadFullItem()
                if item.type == .series {
                    await loadNextEpisode()
                    if let selectedSeasonID {
                        await loadEpisodes(seasonID: selectedSeasonID)
                    }
                }
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                backdrop
                scrim
            }
            .ignoresSafeArea(edges: [.top, .horizontal])

            HStack(alignment: .center, spacing: 60) {
                poster

                VStack(alignment: .leading, spacing: 24) {
                    titleBlock
                    metadataRow
                    genresText
                    overviewText
                    buttonsRow
                }
                .frame(maxWidth: 900, alignment: .leading)

                Spacer()
            }
            .padding(.horizontal, 90)
            .padding(.bottom, 90)
        }
        .clipped()
    }

    // MARK: - Episodes

    private var episodesSection: some View {
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
            await loadEpisodes(seasonID: selectedSeasonID)
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
            HStack(alignment: .top, spacing: 32) {
                ForEach(episodes, id: \.id) { episode in
                    EpisodeCard(
                        episode: episode,
                        isDefaultFocus: episode.id == episodes.first?.id,
                        focusNamespace: episodesNamespace,
                        onPlay: startPlayback
                    )
                }
            }
            .padding(.horizontal, 90)
        }
        .scrollClipDisabled()
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
        .frame(width: 320, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
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

    // MARK: - Metadata

    private var metadataRow: some View {
        HStack(spacing: 20) {
            if let year = item.productionYear {
                Text(year, format: .number.grouping(.never))
            }

            if let rating = item.communityRating {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                    Text(String(format: "%.1f", rating))
                }
            }

            if let durationText {
                Text(durationText)
            }

            if let officialRating = item.officialRating {
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
        if item.type == .series {
            let seasonCount = item.childCount ?? 1
            return seasonCount == 1 ? "1 Season" : "\(seasonCount) Seasons"
        }

        guard let ticks = item.runTimeTicks else { return nil }
        let totalMinutes = Int(Double(ticks) / 600_000_000)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
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
            Button(action: play) {
                Label(playLabel, systemImage: "play.fill")
            }
            .buttonStyle(DetailActionButtonStyle(emphasis: .primary))
            .prefersDefaultFocus(true, in: heroNamespace)
            .focused($isPlayButtonFocused)

            if localTrailer != nil || trailerURL != nil {
                Button {
                    if let localTrailer {
                        startPlayback(for: localTrailer)
                    } else if let trailerURL {
                        openURL(trailerURL)
                    }
                } label: {
                    Label("Trailer", systemImage: "film")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
            }

            Button(action: toggleWatchlist) {
                Label(isWatchlist ? "In Watchlist" : "Add to Watchlist", systemImage: isWatchlist ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
            .disabled(isTogglingWatchlist)
        }
    }

    private var playLabel: String {
        if item.type == .series {
            guard let nextEpisode else { return "Play" }
            let season = nextEpisode.parentIndexNumber ?? 1
            let episode = nextEpisode.indexNumber ?? 1
            return "Play S\(season) E\(episode)"
        }

        let hasProgress = (item.userData?.playbackPositionTicks ?? 0) > 0 && item.userData?.isPlayed != true
        return hasProgress ? "Resume" : "Play"
    }

    private func play() {
        let target = item.type == .series ? nextEpisode : item
        guard let target else { return }
        startPlayback(for: target)
    }

    private func startPlayback(for target: BaseItemDto) {
        guard target.id != nil else { return }
        let startTicks = target.userData?.playbackPositionTicks ?? 0
        playbackTarget = PlaybackTarget(item: target, startTicks: startTicks)
    }

    private func toggleWatchlist() {
        guard let client = appState.client, let id = item.id, !isTogglingWatchlist else { return }
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

    private func loadFullItem() async {
        guard let client = appState.client, let id = item.id else { return }
        do {
            let full = try await client.send(Paths.getItem(itemID: id, userID: appState.currentUser?.id)).value
            item = full
            isWatchlist = full.userData?.isLikes ?? false
        } catch {
            // The stub data passed in from the grid is enough to render the page.
        }
    }

    private func loadLocalTrailer() async {
        guard let client = appState.client, let id = item.id, (item.localTrailerCount ?? 0) > 0 else { return }
        do {
            let trailers = try await client.send(Paths.getLocalTrailers(itemID: id, userID: appState.currentUser?.id)).value
            localTrailer = trailers.first
        } catch {
            localTrailer = nil
        }
    }

    private func loadNextEpisode() async {
        guard let client = appState.client, let seriesID = item.id else { return }
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

    private func loadSeasons() async {
        guard let client = appState.client, let seriesID = item.id else { return }
        do {
            let result = try await client.send(Paths.getSeasons(seriesID: seriesID, parameters: .init(
                userID: appState.currentUser?.id
            ))).value
            seasons = result.items ?? []
            selectedSeasonID = seasons.first(where: { $0.indexNumber == nextEpisode?.parentIndexNumber })?.id ?? seasons.first?.id
        } catch {
            // The episodes section just won't show if seasons fail to load.
        }
    }

    private func loadEpisodes(seasonID: String) async {
        guard let client = appState.client, let seriesID = item.id else { return }
        do {
            let result = try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: .init(
                userID: appState.currentUser?.id,
                seasonID: seasonID,
                enableUserData: true
            ))).value
            episodes = result.items ?? []
        } catch {
            episodes = []
        }
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

    private var trailerURL: URL? {
        item.remoteTrailers?.first?.url.flatMap(URL.init(string:))
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
                    .foregroundStyle(.secondary)
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
                        image.resizable().scaledToFill()
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
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
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
            parameters: .init(fillWidth: 840, fillHeight: 473, tag: episode.imageTags?["Primary"])
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}

#Preview {
    ItemDetailView(item: BaseItemDto(name: "Preview Item", overview: "A short preview overview."))
        .environmentObject(AppState())
}
