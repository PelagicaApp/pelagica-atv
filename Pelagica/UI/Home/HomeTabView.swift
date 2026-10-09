//
//  HomeTabView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configStore: AppConfigStore
    @EnvironmentObject private var seerrStore: SeerrStore

    @State private var slots: [HomeSlot] = []
    @State private var isLoadingConfig = true
    @State private var path = NavigationPath()
    @State private var mediaBarItems: [BaseItemDto] = []
    @State private var mediaBarShowFavoriteButton = false
    @State private var mediaBarShowWatchlistButton = false
    @State private var hasMediaBarSection = false

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ZStack {
                    PelagicaBackground()

                    if isLoadingConfig {
                        ProgressView()
                            .tint(.white)
                    } else {
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 30) {
                                    if hasMediaBarSection {
                                        Group {
                                            if mediaBarItems.isEmpty {
                                                SkeletonView()
                                            } else {
                                                HomeMediaBar(
                                                    items: mediaBarItems,
                                                    showFavoriteButton: mediaBarShowFavoriteButton,
                                                    showWatchlistButton: mediaBarShowWatchlistButton,
                                                    onButtonFocused: {
                                                        withAnimation {
                                                            scrollProxy.scrollTo(Self.topScrollAnchor, anchor: .top)
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .frame(height: proxy.size.height * 0.82)
                                        .focusSection()
                                        .id(Self.topScrollAnchor)

                                        Color.clear.frame(height: 40)
                                    }

                                    ForEach(slots) { slot in
                                        if slot.isLoading {
                                            loadingRow(kind: slot.skeletonKind, title: slot.title)
                                                .focusSection()
                                        } else {
                                            ForEach(slot.rows) { row in
                                                if !row.isEmpty {
                                                    rowView(for: row)
                                                        .focusSection()
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, hasMediaBarSection ? 0 : 60)
                                .padding(.bottom, 60)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: hasMediaBarSection ? [.top, .horizontal] : [])
            .pelagicaDestinations()
            .navigationDestination(for: GenreRoute.self) { route in
                LibraryItemsView(genre: route)
            }
            .navigationDestination(for: StudioRoute.self) { route in
                LibraryItemsView(studio: route)
            }
            .navigationDestination(for: StudiosRoute.self) { _ in
                StudiosView()
            }
        }
        .onDisappear { path = NavigationPath() }
        // Reloads when Seerr is logged in or out from Settings, so its rows appear or disappear
        .task(id: seerrStore.isLoggedIn) { await loadHome() }
        .onChange(of: appState.watchStateVersion) {
            Task { await refreshProgressRows() }
        }
    }

    private static let topScrollAnchor = "homeTop"

    private func loadingRow(kind: HomeSlot.SkeletonKind, title: String?) -> some View {
        HomeSectionRow(title: title ?? "", isLoadingTitle: title == nil) {
            ForEach(0..<5, id: \.self) { _ in
                switch kind {
                case .poster:
                    SkeletonView()
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(width: 280)
                case .landscape:
                    SkeletonView()
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(width: 420)
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(for row: HomeRow) -> some View {
        switch row.kind {
        case .poster(let detailText, let useThumb, let autoPlayTrailers):
            HomeSectionRow(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    ItemCard(item: row.items[index], detailText: detailText, useThumb: useThumb, autoPlayTrailer: autoPlayTrailers)
                        .frame(width: useThumb ? 420 : 280)
                }
            }

        case .recommended(let recommendations, let showSimilarity):
            HomeSectionRow(title: row.title) {
                ForEach(recommendations.indices, id: \.self) { index in
                    let recommendation = recommendations[index]
                    ItemCard(
                        item: recommendation.item,
                        similarity: showSimilarity ? recommendation.similarity : nil
                    )
                    .frame(width: 280)
                }
            }

        case .continueStyle(let titleLine, let detailLines):
            HomeSectionRow(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    let item = row.items[index]
                    ContinueWatchingCard(
                        item: item,
                        titleText: Self.titleLineText(for: item, titleLine: titleLine),
                        detailText: Self.detailLineText(for: item, lines: detailLines)
                    )
                    .frame(width: 420)
                }
            }

        case .library:
            HomeSectionRow(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    HomeLibraryCard(library: row.items[index])
                        .frame(width: 420)
                }
            }

        case .genres(let genres):
            HomeSectionRow(title: row.title) {
                ForEach(genres) { genre in
                    HomeGenreCard(genre: genre)
                        .frame(width: 420)
                }
            }

        case .studios(let studios):
            HomeSectionRow(title: row.title) {
                ForEach(studios) { studio in
                    HomeStudioCard(studio: studio)
                        .frame(width: 420)
                }
                HomeStudiosMoreCard()
                    .frame(width: 420)
            }

        case .seerr(let items):
            HomeSectionRow(title: row.title) {
                ForEach(items) { item in
                    SeerrItemCard(item: item)
                        .frame(width: 280)
                }
            }
        }
    }

    // MARK: - Loading

    private func loadHome() async {
        guard let client = appState.client else {
            isLoadingConfig = false
            return
        }

        let allSections = configStore.config.homeScreenSections ?? []

        let mediaBarSection = allSections.compactMap { section -> MediaBarSection? in
            guard case .mediaBar(let mediaBar) = section else { return nil }
            return mediaBar
        }.first
        hasMediaBarSection = mediaBarSection != nil
        mediaBarShowFavoriteButton = mediaBarSection?.showFavoriteButton ?? false
        mediaBarShowWatchlistButton = mediaBarSection?.showWatchlistButton ?? false

        let sections = allSections.filter { section in
            if case .mediaBar = section { return false }
            return true
        }

        slots = sections.map { HomeSlot(skeletonKind: Self.skeletonKind(for: $0), title: Self.placeholderTitle(for: $0)) }
        isLoadingConfig = false

        enum LoadResult {
            case rows(index: Int, [HomeRow])
            case mediaBar([BaseItemDto])
        }

        await withTaskGroup(of: LoadResult.self) { group in
            if let mediaBarSection {
                group.addTask {
                    .mediaBar(await self.fetchItems(config: mediaBarSection.items, client: client, fallbackLimit: 10))
                }
            }

            for (index, section) in sections.enumerated() {
                group.addTask {
                    .rows(index: index, await self.fetchRows(for: section, client: client))
                }
            }

            for await result in group {
                switch result {
                case .rows(let index, let rows):
                    slots[index] = HomeSlot(rows: rows, isLoading: false)
                case .mediaBar(let items):
                    mediaBarItems = items
                    // Empty result doesn't leave media bar loading forever
                    if items.isEmpty { hasMediaBarSection = false }
                }
            }
        }
    }

    private func refreshProgressRows() async {
        guard let client = appState.client, !isLoadingConfig else { return }

        let sections = (configStore.config.homeScreenSections ?? []).filter { section in
            if case .mediaBar = section { return false }
            return true
        }
        guard sections.count == slots.count else { return }

        await withTaskGroup(of: (Int, [HomeRow]).self) { group in
            for (index, section) in sections.enumerated() where Self.showsProgress(section) {
                group.addTask {
                    (index, await self.fetchRows(for: section, client: client))
                }
            }

            for await (index, rows) in group where index < slots.count {
                let oldRows = slots[index].rows
                slots[index].rows = rows.enumerated().map { offset, row in
                    var row = row
                    if offset < oldRows.count { row.id = oldRows[offset].id }
                    return row
                }
                slots[index].isLoading = false
            }
        }
    }

    nonisolated private static func showsProgress(_ section: HomeScreenSection) -> Bool {
        switch section {
        case .continueWatching, .nextUp, .resume:
            return true
        default:
            return false
        }
    }

    private func fetchRows(for section: HomeScreenSection, client: JellyfinClient) async -> [HomeRow] {
        switch section {
        case .continueWatching(let section):
            let items = await fetchContinueWatching(client: client, limit: section.limit.orDefaultLimit(20))
            return [HomeRow(
                title: section.title.orDefault(i18n.t("home:continue_watching")),
                items: items,
                kind: .continueStyle(titleLine: section.titleLine, detailLines: section.detailLine)
            )]

        case .nextUp(let section):
            let items = await fetchNextUp(client: client, limit: section.limit.orDefaultLimit(20))
            return [HomeRow(
                title: section.title.orDefault(i18n.t("home:next_up")),
                items: items,
                kind: .continueStyle(titleLine: section.titleLine, detailLines: section.detailLine)
            )]
            
        case .resume(let section):
            let items = await fetchResume(client: client, limit: section.limit.orDefaultLimit(20))
            return [HomeRow(
                title: section.title.orDefault(i18n.t("resume")),
                items: items,
                kind: .continueStyle(titleLine: section.titleLine, detailLines: section.detailLine)
            )]

        case .recentlyAdded(let section):
            return await fetchRecentlyAddedRows(section: section, client: client)

        case .items(let section):
            let items = await fetchItems(config: section.items, client: client, fallbackLimit: 20)
            let fields = section.detailFields
            let useThumb = section.useThumbImage ?? false
            return [HomeRow(
                title: section.title ?? "",
                items: items,
                kind: .poster(
                    detailText: { Self.detailFieldsText(for: $0, fields: fields) },
                    useThumb: useThumb,
                    autoPlayTrailers: useThumb && section.autoPlayTrailers == true
                )
            )]

        case .libraries(let section):
            let items = await fetchLibraries(client: client)
            guard !items.isEmpty else { return [] }
            return [HomeRow(title: section.title.orDefault(i18n.t("home:libraries")), items: items, kind: .library)]

        case .genres(let section):
            let genres = await fetchGenres(client: client, limit: section.limit.orDefaultLimit(20))
            guard !genres.isEmpty else { return [] }
            return [HomeRow(title: section.title.orDefault(i18n.t("genres")), items: [], kind: .genres(genres))]

        case .studios(let section):
            guard let userID = appState.currentUser?.id else { return [] }
            let studios = await StudiosAPI.fetchStudiosByItemCount(client: client, userID: userID)
            guard !studios.isEmpty else { return [] }
            return [HomeRow(
                title: section.title.orDefault(i18n.t("studios")),
                items: [],
                kind: .studios(Array(studios.prefix(section.limit.orDefaultLimit(20))))
            )]

        case .streamystatsRecommended(let section):
            guard let userID = appState.currentUser?.id, let streamystatsURL = configStore.config.streamystatsURL, !streamystatsURL.isEmpty else { return [] }
            let recommendations = await StreamystatsAPI.fetchRecommendations(
                streamystatsURL: streamystatsURL,
                type: section.recommendationType,
                limit: section.limit.orDefaultLimit(20),
                client: client,
                userID: userID
            )
            guard !recommendations.isEmpty else { return [] }
            return [HomeRow(
                title: section.title.orDefault(i18n.t("home:recommended_for_you")),
                items: [],
                kind: .recommended(
                    recommendations,
                    showSimilarity: section.showSimilarity ?? true
                )
            )]

        case .seerrDiscover(let section):
            let variant = section.variant
            let items = await seerrStore.items { try await $0.discover(variant) }
            guard !items.isEmpty else { return [] }
            return [HomeRow(
                title: section.title.orDefault(Self.seerrDiscoverTitle(variant)),
                items: [],
                kind: .seerr(items)
            )]

        case .mediaBar, .unsupported:
            return []
        }
    }

    nonisolated private static func seerrDiscoverTitle(_ variant: SeerrDiscoverVariant) -> String {
        switch variant {
        case .trending: i18n.t("home:seerr_trending")
        case .popularMovies: i18n.t("home:seerr_popular_movies")
        case .popularSeries: i18n.t("home:seerr_popular_series")
        }
    }

    // MARK: - Fetching

    private static let genreItemTypes: [BaseItemKind] = [.movie, .series]

    private func fetchGenres(client: JellyfinClient, limit: Int) async -> [GenreEntry] {
        guard let userID = appState.currentUser?.id else { return [] }

        let genres: [BaseItemDto]
        do {
            genres = try await client.send(Paths.getGenres(parameters: .init(
                limit: limit,
                includeItemTypes: Self.genreItemTypes,
                userID: userID,
                sortBy: [.sortName],
                sortOrder: [.ascending]
            ))).value.items ?? []
        } catch {
            return []
        }

        let entries = await withTaskGroup(of: GenreEntry?.self) { group in
            for genre in genres {
                guard let id = genre.id, let name = genre.name else { continue }
                group.addTask {
                    let result = try? await client.send(Paths.getItems(parameters: .init(
                        userID: userID,
                        limit: 1,
                        isRecursive: true,
                        excludeItemTypes: [.collectionFolder],
                        includeItemTypes: Self.genreItemTypes,
                        sortBy: [.random],
                        genreIDs: [id]
                    ))).value
                    let item = result?.items?.first
                    return GenreEntry(
                        id: id,
                        name: name,
                        artwork: item.flatMap(GenreArtwork.init),
                        totalItems: result?.totalRecordCount ?? 0
                    )
                }
            }

            var entries: [GenreEntry] = []
            for await entry in group {
                if let entry { entries.append(entry) }
            }
            return entries
        }

        return entries
            .filter { $0.totalItems > 0 }
            .sorted { lhs, rhs in
                lhs.totalItems != rhs.totalItems ? lhs.totalItems > rhs.totalItems : lhs.name < rhs.name
            }
    }

    private static let supportedLibraryCollectionTypes: Set<CollectionType> = [.movies, .tvshows, .boxsets]

    private func fetchLibraries(client: JellyfinClient) async -> [BaseItemDto] {
        guard let userID = appState.currentUser?.id else { return [] }
        do {
            let result = try await client.send(Paths.getUserViews(parameters: .init(userID: userID))).value
            return (result.items ?? []).filter { view in
                view.collectionType.map(Self.supportedLibraryCollectionTypes.contains) ?? false
            }
        } catch {
            return []
        }
    }

    private func fetchItems(config: SectionItemsConfig?, client: JellyfinClient, fallbackLimit: Int) async -> [BaseItemDto] {
        guard let userID = appState.currentUser?.id else { return [] }

        var filters: [ItemFilter] = []
        if config?.isUnplayed == true { filters.append(.isUnplayed) }
        if config?.isInKefinTweaksWatchlist == true { filters.append(.likes) }

        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: userID,
                locationTypes: [.fileSystem],
                limit: config?.limit.orDefaultLimit(fallbackLimit) ?? fallbackLimit,
                isRecursive: true,
                sortOrder: [config?.sortOrder ?? .descending],
                parentID: config?.libraryID,
                fields: [.overview, .genres],
                includeItemTypes: (config?.types?.isEmpty == false) ? config?.types : [.movie, .series],
                filters: filters,
                isFavorite: config?.isFavorite,
                sortBy: config?.sortBy ?? [.random],
                genres: config?.genres,
                tags: config?.tags,
                enableUserData: true
            ))).value
            return result.items ?? []
        } catch {
            return []
        }
    }

    private func fetchContinueWatching(client: JellyfinClient, limit: Int) async -> [BaseItemDto] {
        guard let userID = appState.currentUser?.id else { return [] }
        async let resume: [BaseItemDto] = {
            do {
                let result = try await client.send(Paths.getResumeItems(parameters: .init(
                    userID: userID,
                    limit: limit * 2,
                    fields: [.overview],
                    enableUserData: true,
                    includeItemTypes: [.movie, .episode]
                ))).value
                return result.items ?? []
            } catch {
                return []
            }
        }()
        async let nextUp: [BaseItemDto] = fetchNextUpItems(client: client, userID: userID, limit: limit, enableResumable: nil)

        var seen = Set<String>()
        let merged = (await resume + (await nextUp)).filter { item in
            guard let id = item.id, !seen.contains(id) else { return false }
            seen.insert(id)
            return true
        }

        let sorted = merged.sorted { lhs, rhs in
            Self.recencyDate(for: lhs) > Self.recencyDate(for: rhs)
        }
        return Array(sorted.prefix(limit))
    }

    private func fetchNextUp(client: JellyfinClient, limit: Int) async -> [BaseItemDto] {
        guard let userID = appState.currentUser?.id else { return [] }
        return await fetchNextUpItems(client: client, userID: userID, limit: limit, enableResumable: false)
    }

    private func fetchNextUpItems(client: JellyfinClient, userID: String, limit: Int, enableResumable: Bool?) async -> [BaseItemDto] {
        do {
            let result = try await client.send(Paths.getNextUp(parameters: .init(
                userID: userID,
                limit: limit,
                fields: [.overview],
                enableUserData: true,
                enableResumable: enableResumable
            ))).value
            return result.items ?? []
        } catch {
            return []
        }
    }
    
    private func fetchResume(client: JellyfinClient, limit: Int) async -> [BaseItemDto] {
        guard let userID = appState.currentUser?.id else { return [] }
        return await fetchResumeItems(client: client, userID: userID, limit: limit)
    }
    
    private func fetchResumeItems(client: JellyfinClient, userID: String, limit: Int) async -> [BaseItemDto] {
        do {
            let result = try await client.send(Paths.getResumeItems(parameters: .init(
                userID: userID,
                limit: limit,
                fields: [.overview],
                enableUserData: true,
            ))).value
            return result.items ?? []
        } catch {
            return []
        }
    }

    private func fetchRecentlyAddedRows(section: RecentlyAddedSection, client: JellyfinClient) async -> [HomeRow] {
        guard let userID = appState.currentUser?.id else { return [] }

        let views: [BaseItemDto]
        do {
            views = try await client.send(Paths.getUserViews(parameters: .init(userID: userID))).value.items ?? []
        } catch {
            return []
        }

        let supportedTypes: [CollectionType: [BaseItemKind]] = [
            .movies: [.movie],
            .tvshows: [.series],
            .boxsets: [.boxSet],
        ]

        let libraries = views.filter { view in
            guard let collectionType = view.collectionType, supportedTypes[collectionType] != nil else { return false }
            if let libraryIDs = section.libraryIDs, !libraryIDs.isEmpty {
                return view.id.map(libraryIDs.contains) ?? false
            }
            return true
        }

        return await withTaskGroup(of: (Int, HomeRow?).self) { group in
            for (index, library) in libraries.enumerated() {
                group.addTask {
                    guard
                        let libraryID = library.id,
                        let name = library.name,
                        let collectionType = library.collectionType
                    else { return (index, nil) }

                    do {
                        let result = try await client.send(Paths.getItems(parameters: .init(
                            userID: userID,
                            limit: section.limit.orDefaultLimit(10),
                            isRecursive: true,
                            sortOrder: [.descending],
                            parentID: libraryID,
                            fields: [.overview],
                            includeItemTypes: supportedTypes[collectionType],
                            sortBy: [.dateCreated],
                            enableUserData: true
                        ))).value
                        guard let items = result.items, !items.isEmpty else { return (index, nil) }
                        return (index, HomeRow(title: i18n.t("home:recently_added", ["category": name]), items: items, kind: .poster(detailText: Self.defaultDetailText, useThumb: false, autoPlayTrailers: false)))
                    } catch {
                        return (index, nil)
                    }
                }
            }

            var rows = [HomeRow?](repeating: nil, count: libraries.count)
            for await (index, row) in group {
                rows[index] = row
            }
            return rows.compactMap { $0 }
        }
    }

    nonisolated private static func skeletonKind(for section: HomeScreenSection) -> HomeSlot.SkeletonKind {
        switch section {
        case .continueWatching, .nextUp, .resume, .libraries, .genres, .studios:
            return .landscape
        case .items(let section):
            return section.useThumbImage == true ? .landscape : .poster
        case .recentlyAdded, .streamystatsRecommended, .seerrDiscover, .mediaBar, .unsupported:
            return .poster
        }
    }

    nonisolated private static func placeholderTitle(for section: HomeScreenSection) -> String? {
        switch section {
        case .continueWatching(let section):
            return section.title.orDefault(i18n.t("home:continue_watching"))
        case .nextUp(let section):
            return section.title.orDefault(i18n.t("home:next_up"))
        case .resume(let section):
            return section.title.orDefault(i18n.t("resume"))
        case .items(let section):
            return section.title ?? ""
        case .libraries(let section):
            return section.title.orDefault(i18n.t("home:libraries"))
        case .genres(let section):
            return section.title.orDefault(i18n.t("genres"))
        case .studios(let section):
            return section.title.orDefault(i18n.t("studios"))
        case .streamystatsRecommended(let section):
            return section.title.orDefault(i18n.t("home:recommended_for_you"))
        case .seerrDiscover(let section):
            return section.title.orDefault(seerrDiscoverTitle(section.variant))
        case .recentlyAdded, .mediaBar, .unsupported:
            return nil
        }
    }

    // MARK: - Text formatting

    nonisolated private static func defaultDetailText(_ item: BaseItemDto) -> String {
        item.premiereDate.map { String(Calendar.current.component(.year, from: $0)) } ?? ""
    }

    nonisolated static func titleLineText(for item: BaseItemDto, titleLine: ContinueWatchingTitleLine?) -> String {
        let fallbackName = item.name ?? item.seriesName ?? i18n.t("no_title")
        switch titleLine ?? .itemTitleWithEpisodeInfo {
        case .itemTitle:
            return item.name ?? i18n.t("no_title")
        case .parentTitle:
            return item.seriesName ?? item.name ?? i18n.t("no_title")
        case .itemTitleWithEpisodeInfo:
            if item.seriesID != nil, let season = item.parentIndexNumber, let episode = item.indexNumber {
                return "S\(season):E\(episode) - \(fallbackName)"
            }
            return fallbackName
        }
    }

    nonisolated static func detailLineText(for item: BaseItemDto, lines: [ContinueWatchingDetailLine]?) -> String {
        let lines = (lines?.isEmpty == false) ? lines! : [.timeRemaining]
        let parts: [String] = lines.compactMap { line in
            switch line {
            case .progressPercentage:
                guard let runtime = item.runTimeTicks, runtime > 0 else { return nil }
                let watched = item.userData?.playbackPositionTicks ?? 0
                return i18n.t("home:progress_watched", ["percent": Int(Double(watched) / Double(runtime) * 100)])
            case .timeRemaining:
                guard let runtime = item.runTimeTicks, runtime > 0 else { return nil }
                let watched = item.userData?.playbackPositionTicks ?? 0
                return i18n.t("home:time_remaining", ["time": readableTime(ticks: max(runtime - watched, 0))])
            case .endsAt:
                guard let runtime = item.runTimeTicks, runtime > 0 else { return nil }
                let watched = item.userData?.playbackPositionTicks ?? 0
                let remainingSeconds = Double(max(runtime - watched, 0)) / 10_000_000
                let endsAt = Date().addingTimeInterval(remainingSeconds)
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return i18n.t("ends_at", ["date": formatter.string(from: endsAt)])
            case .episodeInfo:
                guard let season = item.parentIndexNumber, let episode = item.indexNumber else { return nil }
                return "S\(season):E\(episode)"
            case .parentTitle:
                return item.seriesName
            case .none:
                return nil
            }
        }
        return parts.joined(separator: " • ")
    }

    nonisolated static func detailFieldsText(for item: BaseItemDto, fields: [DetailField]?) -> String {
        guard let fields, !fields.isEmpty else { return defaultDetailText(item) }
        let parts: [String] = fields.compactMap { field in
            switch field {
            case .releaseYear:
                return item.premiereDate.map { String(Calendar.current.component(.year, from: $0)) }
            case .releaseYearAndMonth, .releaseDate:
                guard let date = item.premiereDate else { return nil }
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate(field == .releaseDate ? "MMMMdyyyy" : "MMMMyyyy")
                return formatter.string(from: date)
            case .communityRating:
                return item.communityRating.map { String(format: "★ %.1f", $0) }
            case .playDuration:
                return item.runTimeTicks.map { readableTime(ticks: $0) }
            case .playEnd:
                guard let runtime = item.runTimeTicks else { return nil }
                let endsAt = Date().addingTimeInterval(Double(runtime) / 10_000_000)
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return i18n.t("ends_at", ["date": formatter.string(from: endsAt)])
            case .seasonCount:
                return item.childCount.map { i18n.t("season_count", count: $0) }
            case .episodeCount:
                return item.recursiveItemCount.map { i18n.t("episode_count", count: $0) }
            case .ageRating:
                return item.officialRating
            case .artist:
                return item.albumArtist
            case .trackCount:
                return item.childCount.map { i18n.t("home:track_count", count: $0) }
            }
        }
        return parts.joined(separator: " • ")
    }

    nonisolated private static func readableTime(ticks: Int) -> String {
        let totalMinutes = ticks / 10_000_000 / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    nonisolated private static func recencyDate(for item: BaseItemDto) -> Date {
        item.userData?.lastPlayedDate ?? item.dateCreated ?? .distantPast
    }
}

private extension Optional where Wrapped == Int {
    /// Falls back to `fallback` when the limit is missing or not positive, since configs may send `0`.
    nonisolated func orDefaultLimit(_ fallback: Int) -> Int {
        guard let self, self > 0 else { return fallback }
        return self
    }
}

private extension Optional where Wrapped == String {
    /// Falls back to `fallback` when the title is missing or empty, since configs may send `""`.
    nonisolated func orDefault(_ fallback: String) -> String {
        guard let self, !self.isEmpty else { return fallback }
        return self
    }
}

private enum HomeRowKind {
    case poster(detailText: (BaseItemDto) -> String, useThumb: Bool, autoPlayTrailers: Bool)
    case continueStyle(titleLine: ContinueWatchingTitleLine?, detailLines: [ContinueWatchingDetailLine]?)
    case library
    case genres([GenreEntry])
    case studios([StudioEntry])
    case recommended([StreamystatsRecommendation], showSimilarity: Bool)
    case seerr([SeerrMediaItem])
}

private struct HomeRow: Identifiable {
    var id = UUID()
    let title: String
    let items: [BaseItemDto]
    let kind: HomeRowKind

    var isEmpty: Bool {
        switch kind {
        case .genres(let genres): return genres.isEmpty
        case .studios(let studios): return studios.isEmpty
        case .recommended(let recommendations, _): return recommendations.isEmpty
        case .seerr(let items): return items.isEmpty
        default: return items.isEmpty
        }
    }
}

private struct HomeSlot: Identifiable {
    enum SkeletonKind {
        case poster
        case landscape
    }

    let id = UUID()
    var rows: [HomeRow] = []
    var isLoading = true
    var skeletonKind: SkeletonKind = .poster
    var title: String?
}

#Preview {
    HomeTabView()
        .environmentObject(AppState())
        .environmentObject(AppConfigStore())
        .environmentObject(SeerrStore())
}
