//
//  HomeScreenConfig.swift
//  Pelagica
//

import Foundation
import JellyfinAPI

struct SectionItemsConfig: Decodable {
    var sortBy: [ItemSortBy]?
    var libraryID: String?
    var types: [BaseItemKind]?
    var genres: [String]?
    var tags: [String]?
    var sortOrder: JellyfinAPI.SortOrder?
    var limit: Int?
    var isFavorite: Bool?
    var isInKefinTweaksWatchlist: Bool?
    var isUnplayed: Bool?

    enum CodingKeys: String, CodingKey {
        case sortBy, types, genres, tags, sortOrder, limit, isFavorite, isUnplayed, isInKefinTweaksWatchlist
        case libraryID = "libraryId"
    }
}

/// Mirrors the web client's `DETAIL_FIELDS`, shown as small text chips under
/// items in a generic `items` section.
enum DetailField: String, Decodable {
    case releaseYear = "ReleaseYear"
    case releaseYearAndMonth = "ReleaseYearAndMonth"
    case releaseDate = "ReleaseDate"
    case communityRating = "CommunityRating"
    case playDuration = "PlayDuration"
    case playEnd = "PlayEnd"
    case seasonCount = "SeasonCount"
    case episodeCount = "EpisodeCount"
    case ageRating = "AgeRating"
    case artist = "Artist"
    case trackCount = "TrackCount"
}

enum ContinueWatchingTitleLine: String, Decodable {
    case itemTitle = "ItemTitle"
    case parentTitle = "ParentTitle"
    case itemTitleWithEpisodeInfo = "ItemTitleWithEpisodeInfo"
}

enum ContinueWatchingDetailLine: String, Decodable {
    case progressPercentage = "ProgressPercentage"
    case timeRemaining = "TimeRemaining"
    case episodeInfo = "EpisodeInfo"
    case endsAt = "EndsAt"
    case parentTitle = "ParentTitle"
    case none = "None"
}

struct MediaBarSection: Decodable {
    var title: String?
    var items: SectionItemsConfig?
    var showFavoriteButton: Bool?
    var showWatchlistButton: Bool?
}

struct RecentlyAddedSection: Decodable {
    var title: String?
    var limit: Int?
    var libraryIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case title, limit
        case libraryIDs = "libraryIds"
    }
}

struct ItemsSection: Decodable {
    var title: String?
    var items: SectionItemsConfig?
    var detailFields: [DetailField]?
}

struct ContinueWatchingSection: Decodable {
    var title: String?
    var titleLine: ContinueWatchingTitleLine?
    var detailLine: [ContinueWatchingDetailLine]?
    var limit: Int?
}

struct NextUpSection: Decodable {
    var title: String?
    var titleLine: ContinueWatchingTitleLine?
    var detailLine: [ContinueWatchingDetailLine]?
    var limit: Int?
}

enum HomeScreenSection: Decodable {
    case mediaBar(MediaBarSection)
    case recentlyAdded(RecentlyAddedSection)
    case items(ItemsSection)
    case continueWatching(ContinueWatchingSection)
    case nextUp(NextUpSection)
    case unsupported

    private enum CodingKeys: String, CodingKey {
        case type, enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if try container.decodeIfPresent(Bool.self, forKey: .enabled) == false {
            self = .unsupported
            return
        }

        switch try container.decode(String.self, forKey: .type) {
        case "mediaBar": self = .mediaBar(try MediaBarSection(from: decoder))
        case "recentlyAdded": self = .recentlyAdded(try RecentlyAddedSection(from: decoder))
        case "items": self = .items(try ItemsSection(from: decoder))
        case "continueWatching": self = .continueWatching(try ContinueWatchingSection(from: decoder))
        case "nextUp": self = .nextUp(try NextUpSection(from: decoder))
        default: self = .unsupported
        }
    }
}

struct HomeScreenConfig: Decodable {
    var homeScreenSections: [HomeScreenSection]?
}

extension HomeScreenConfig {
    static let fallback = HomeScreenConfig(homeScreenSections: [
        .mediaBar(MediaBarSection(
            items: SectionItemsConfig(sortBy: [.random], types: [.movie, .series]),
            showFavoriteButton: true,
            showWatchlistButton: true
        )),
        .continueWatching(ContinueWatchingSection(
            title: "Continue Watching",
            titleLine: .itemTitleWithEpisodeInfo,
            detailLine: [.timeRemaining],
            limit: 20
        )),
        .items(ItemsSection(
            title: "Favorites",
            items: SectionItemsConfig(limit: 10, isFavorite: true)
        )),
        .nextUp(NextUpSection(title: "Next Up", limit: 20)),
        .recentlyAdded(RecentlyAddedSection(title: "Recently Added", limit: 20)),
    ])
}
