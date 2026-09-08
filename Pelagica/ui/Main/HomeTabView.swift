//
//  HomeTabView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appState: AppState

    @State private var slots: [HomeSlot] = []
    @State private var isLoadingConfig = true
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoadingConfig {
                    ProgressView()
                        .tint(.white)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 30) {
                            ForEach(slots) { slot in
                                if slot.isLoading {
                                    loadingRow(kind: slot.skeletonKind, title: slot.title)
                                        .focusSection()
                                } else {
                                    ForEach(slot.rows) { row in
                                        if !row.items.isEmpty {
                                            rowView(for: row)
                                                .focusSection()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 60)
                    }
                }
            }
            .navigationDestination(for: ItemDetailRoute.self) { route in
                ItemDetailView(item: route.item)
            }
        }
        .onDisappear { path = NavigationPath() }
        .task { await loadHome() }
    }

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
        case .poster(let detailText):
            HomeSectionRow(title: row.title) {
                ForEach(row.items.indices, id: \.self) { index in
                    ItemCard(item: row.items[index], detailText: detailText)
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
        }
    }

    // MARK: - Loading

    private func loadHome() async {
        guard let client = appState.client else {
            isLoadingConfig = false
            return
        }

        let config = await PelagicaPluginAPI.fetchHomeScreenConfig(serverURL: client.configuration.url)
        let sections = config.homeScreenSections ?? []

        slots = sections.map { HomeSlot(skeletonKind: Self.skeletonKind(for: $0), title: Self.placeholderTitle(for: $0)) }
        isLoadingConfig = false

        await withTaskGroup(of: (Int, [HomeRow]).self) { group in
            for (index, section) in sections.enumerated() {
                group.addTask {
                    (index, await self.fetchRows(for: section, client: client))
                }
            }

            for await (index, rows) in group {
                slots[index] = HomeSlot(rows: rows, isLoading: false)
            }
        }
    }

    private func fetchRows(for section: HomeScreenSection, client: JellyfinClient) async -> [HomeRow] {
        switch section {
        case .continueWatching(let section):
            let items = await fetchContinueWatching(client: client, limit: section.limit ?? 20)
            return [HomeRow(
                title: section.title ?? "Continue Watching",
                items: items,
                kind: .continueStyle(titleLine: section.titleLine, detailLines: section.detailLine)
            )]

        case .nextUp(let section):
            let items = await fetchNextUp(client: client, limit: section.limit ?? 20)
            return [HomeRow(
                title: section.title ?? "Next Up",
                items: items,
                kind: .continueStyle(titleLine: section.titleLine, detailLines: section.detailLine)
            )]

        case .recentlyAdded(let section):
            return await fetchRecentlyAddedRows(section: section, client: client)

        case .items(let section):
            let items = await fetchItems(config: section.items, client: client, fallbackLimit: 20)
            let fields = section.detailFields
            return [HomeRow(
                title: section.title ?? "",
                items: items,
                kind: .poster(detailText: { Self.detailFieldsText(for: $0, fields: fields) })
            )]

        case .unsupported:
            return []
        }
    }

    // MARK: - Fetching

    private func fetchItems(config: SectionItemsConfig?, client: JellyfinClient, fallbackLimit: Int) async -> [BaseItemDto] {
        guard let userID = appState.currentUser?.id else { return [] }

        var filters: [ItemFilter] = []
        if config?.isUnplayed == true { filters.append(.isUnplayed) }
        if config?.isInKefinTweaksWatchlist == true { filters.append(.likes) }

        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: userID,
                locationTypes: [.fileSystem],
                limit: config?.limit ?? fallbackLimit,
                isRecursive: true,
                sortOrder: [config?.sortOrder ?? .descending],
                parentID: config?.libraryID,
                fields: [.overview],
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
                            limit: section.limit ?? 10,
                            isRecursive: true,
                            sortOrder: [.descending],
                            parentID: libraryID,
                            fields: [.overview],
                            includeItemTypes: supportedTypes[collectionType],
                            sortBy: [.dateCreated],
                            enableUserData: true
                        ))).value
                        guard let items = result.items, !items.isEmpty else { return (index, nil) }
                        return (index, HomeRow(title: "Recently Added in \(name)", items: items, kind: .poster(detailText: Self.defaultDetailText)))
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
        case .continueWatching, .nextUp:
            return .landscape
        case .items, .recentlyAdded, .unsupported:
            return .poster
        }
    }

    nonisolated private static func placeholderTitle(for section: HomeScreenSection) -> String? {
        switch section {
        case .continueWatching(let section):
            return section.title ?? "Continue Watching"
        case .nextUp(let section):
            return section.title ?? "Next Up"
        case .items(let section):
            return section.title ?? ""
        case .recentlyAdded, .unsupported:
            return nil
        }
    }

    // MARK: - Text formatting

    nonisolated private static func defaultDetailText(_ item: BaseItemDto) -> String {
        item.premiereDate.map { String(Calendar.current.component(.year, from: $0)) } ?? ""
    }

    nonisolated static func titleLineText(for item: BaseItemDto, titleLine: ContinueWatchingTitleLine?) -> String {
        let fallbackName = item.name ?? item.seriesName ?? "Untitled"
        switch titleLine ?? .itemTitleWithEpisodeInfo {
        case .itemTitle:
            return item.name ?? "Untitled"
        case .parentTitle:
            return item.seriesName ?? item.name ?? "Untitled"
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
                return "\(Int(Double(watched) / Double(runtime) * 100))% watched"
            case .timeRemaining:
                guard let runtime = item.runTimeTicks, runtime > 0 else { return nil }
                let watched = item.userData?.playbackPositionTicks ?? 0
                return "\(readableTime(ticks: max(runtime - watched, 0))) left"
            case .endsAt:
                guard let runtime = item.runTimeTicks, runtime > 0 else { return nil }
                let watched = item.userData?.playbackPositionTicks ?? 0
                let remainingSeconds = Double(max(runtime - watched, 0)) / 10_000_000
                let endsAt = Date().addingTimeInterval(remainingSeconds)
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Ends at \(formatter.string(from: endsAt))"
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
                formatter.dateFormat = field == .releaseDate ? "MMMM d, yyyy" : "MMMM yyyy"
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
                return "Ends at \(formatter.string(from: endsAt))"
            case .seasonCount:
                return item.childCount.map { $0 == 1 ? "1 Season" : "\($0) Seasons" }
            case .episodeCount:
                return item.recursiveItemCount.map { $0 == 1 ? "1 Episode" : "\($0) Episodes" }
            case .ageRating:
                return item.officialRating
            case .artist:
                return item.albumArtist
            case .trackCount:
                return item.childCount.map { $0 == 1 ? "1 Track" : "\($0) Tracks" }
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

private enum HomeRowKind {
    case poster(detailText: (BaseItemDto) -> String)
    case continueStyle(titleLine: ContinueWatchingTitleLine?, detailLines: [ContinueWatchingDetailLine]?)
}

private struct HomeRow: Identifiable {
    let id = UUID()
    let title: String
    let items: [BaseItemDto]
    let kind: HomeRowKind
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
}
