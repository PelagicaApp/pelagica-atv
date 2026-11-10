//
//  SeerrModels.swift
//  Pelagica
//

import Foundation

nonisolated enum SeerrMediaType: String, Codable, Hashable, Sendable {
    case movie
    case tv
}

nonisolated enum SeerrMediaStatus: Int, Decodable, Sendable {
    case unknown = 1
    case pending = 2
    case processing = 3
    case partiallyAvailable = 4
    case available = 5

    init(from decoder: Decoder) throws {
        // Newer Seerr versions add statuses (e.g. blocklisted); treat anything unrecognized as unknown
        self = Self(rawValue: try decoder.singleValueContainer().decode(Int.self)) ?? .unknown
    }
}

nonisolated enum SeerrRequestStatus: Int, Decodable, Sendable {
    case pending = 1
    case approved = 2
    case declined = 3
    case failed = 4
    case completed = 5
    case unknown = 0

    init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(Int.self)) ?? .unknown
    }
}

nonisolated struct SeerrSeasonStatus: Decodable, Hashable, Sendable {
    let seasonNumber: Int
    let status: SeerrMediaStatus
}

nonisolated struct SeerrMediaRequest: Decodable, Hashable, Sendable {
    struct Season: Decodable, Hashable, Sendable {
        let seasonNumber: Int
    }

    let id: Int
    let status: SeerrRequestStatus
    let seasons: [Season]?
}

nonisolated struct SeerrMediaInfo: Decodable, Hashable, Sendable {
    let status: SeerrMediaStatus?
    let jellyfinMediaId: String?
    let seasons: [SeerrSeasonStatus]?
    let requests: [SeerrMediaRequest]?
}

nonisolated struct SeerrMediaItem: Decodable, Hashable, Identifiable, Sendable {
    let tmdbID: Int
    let mediaType: SeerrMediaType
    let title: String
    let posterPath: String?
    let releaseDate: String?
    let mediaInfo: SeerrMediaInfo?

    var id: String { "\(mediaType.rawValue)-\(tmdbID)" }

    var status: SeerrMediaStatus { mediaInfo?.status ?? .unknown }

    var releaseYear: String? { releaseDate.flatMap(SeerrDate.year) }

    private enum CodingKeys: String, CodingKey {
        case id, mediaType, title, name, posterPath, releaseDate, firstAirDate, mediaInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tmdbID = try container.decode(Int.self, forKey: .id)
        mediaType = try container.decode(SeerrMediaType.self, forKey: .mediaType)
        switch mediaType {
        case .movie:
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
            releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        case .tv:
            title = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            releaseDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        }
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        mediaInfo = try container.decodeIfPresent(SeerrMediaInfo.self, forKey: .mediaInfo)
    }
}

nonisolated struct SeerrSeason: Decodable, Hashable, Sendable {
    let seasonNumber: Int
    let name: String?
    let episodeCount: Int?
}

nonisolated struct SeerrRelatedVideo: Decodable, Hashable, Sendable {
    let url: String?
    let key: String?
    let name: String?
    let type: String?
    let site: String?
}

nonisolated struct SeerrDetails: Hashable, Sendable {
    let tmdbID: Int
    let mediaType: SeerrMediaType
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let genres: [String]
    let mediaInfo: SeerrMediaInfo?
    let seasons: [SeerrSeason]
    let relatedVideos: [SeerrRelatedVideo]

    var status: SeerrMediaStatus { mediaInfo?.status ?? .unknown }

    var releaseYear: String? { releaseDate.flatMap(SeerrDate.year) }

    var trailerURL: URL? {
        relatedVideos
            .first { $0.type == "Trailer" && $0.site == "YouTube" }
            .flatMap { $0.url }
            .flatMap(URL.init(string:))
    }
}

nonisolated struct SeerrUser: Decodable, Sendable {
    let id: Int
    let displayName: String?
}

nonisolated enum SeerrDiscoverVariant: String, Sendable {
    case trending
    case popularMovies
    case popularSeries
}

enum SeerrImage {
    private static let base = "https://image.tmdb.org/t/p/"

    static func poster(_ path: String?) -> URL? {
        url(path, size: "w500")
    }

    static func backdrop(_ path: String?) -> URL? {
        url(path, size: "w1280")
    }

    private static func url(_ path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: base + size + path)
    }
}

nonisolated private enum SeerrDate {
    /// Seerr dates are `yyyy-MM-dd` strings.
    static func year(_ date: String) -> String? {
        date.count >= 4 ? String(date.prefix(4)) : nil
    }
}
