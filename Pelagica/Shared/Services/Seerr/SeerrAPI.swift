//
//  SeerrAPI.swift
//  Pelagica
//

import Foundation

nonisolated enum SeerrAPIError: Error {
    case invalidURL
    case unauthorized
    case missingSession
    case badStatus(Int)
}

nonisolated struct SeerrAPI: Sendable {
    private static let sessionCookieName = "connect.sid"

    private static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuration)
    }()

    let baseURL: URL
    let session: String

    init?(seerrURL: String, session: String) {
        guard let baseURL = Self.baseURL(from: seerrURL) else { return nil }
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Auth

    /// Signs in with Jellyfin credentials and returns the session cookie value.
    static func login(seerrURL: String, username: String, password: String) async throws -> String {
        guard let baseURL = baseURL(from: seerrURL) else { throw SeerrAPIError.invalidURL }

        var request = URLRequest(url: endpoint(baseURL, "auth/jellyfin"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["username": username, "password": password])

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SeerrAPIError.badStatus(0) }
        guard http.statusCode == 200 else {
            throw [401, 403].contains(http.statusCode) ? SeerrAPIError.unauthorized : SeerrAPIError.badStatus(http.statusCode)
        }

        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, field in
            if let key = field.key as? String, let value = field.value as? String { result[key] = value }
        }
        let cookie = HTTPCookie.cookies(withResponseHeaderFields: headers, for: request.url!)
            .first { $0.name == sessionCookieName }
        guard let cookie else { throw SeerrAPIError.missingSession }
        return cookie.value
    }

    func logout() async {
        _ = try? await send(path: "auth/logout", method: "POST")
    }

    func currentUser() async throws -> SeerrUser {
        try await get("auth/me")
    }

    // MARK: - Browsing

    func search(query: String) async throws -> [SeerrMediaItem] {
        try await get("search", query: ["query": query, "page": "1"], as: ResultsPage.self).items
    }

    func discover(_ variant: SeerrDiscoverVariant) async throws -> [SeerrMediaItem] {
        let path = switch variant {
        case .trending: "discover/trending"
        case .popularMovies: "discover/movies"
        case .popularSeries: "discover/tv"
        }
        return try await get(path, as: ResultsPage.self).items
    }

    func recommendations(mediaType: SeerrMediaType, tmdbID: Int) async throws -> [SeerrMediaItem] {
        try await get("\(mediaType.rawValue)/\(tmdbID)/recommendations", as: ResultsPage.self).items
    }

    func combinedCredits(personTmdbID: String) async throws -> [SeerrMediaItem] {
        let credits = try await get("person/\(personTmdbID)/combined_credits", as: CombinedCredits.self)
        var seen = Set<String>()
        return (credits.cast + credits.crew)
            .compactMap(\.value)
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
    }

    func details(mediaType: SeerrMediaType, tmdbID: Int) async throws -> SeerrDetails {
        let response = try await get("\(mediaType.rawValue)/\(tmdbID)", as: DetailsResponse.self)
        return SeerrDetails(
            tmdbID: response.id,
            mediaType: mediaType,
            title: (mediaType == .movie ? response.title : response.name) ?? "",
            overview: response.overview,
            posterPath: response.posterPath,
            backdropPath: response.backdropPath,
            releaseDate: mediaType == .movie ? response.releaseDate : response.firstAirDate,
            genres: (response.genres ?? []).map(\.name),
            mediaInfo: response.mediaInfo,
            seasons: response.seasons ?? [],
            relatedVideos: response.relatedVideos ?? []
        )
    }

    // MARK: - Requests

    func request(mediaType: SeerrMediaType, tmdbID: Int, seasons: [Int]? = nil) async throws {
        var payload: [String: Any] = ["mediaType": mediaType.rawValue, "mediaId": tmdbID]
        if mediaType == .tv { payload["seasons"] = seasons ?? [] }
        _ = try await send(path: "request", method: "POST", body: try JSONSerialization.data(withJSONObject: payload))
    }

    // MARK: - Transport

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        let data = try await send(path: path, query: query)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func send(path: String, method: String = "GET", query: [String: String] = [:], body: Data? = nil) async throws -> Data {
        var url = Self.endpoint(baseURL, path)
        if !query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.percentEncodedQueryItems = query.sorted { $0.key < $1.key }.map {
                URLQueryItem(name: $0.key, value: $0.value.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed))
            }
            url = components.url ?? url
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        request.setValue("\(Self.sessionCookieName)=\(session)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await Self.urlSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if [401, 403].contains(status) { throw SeerrAPIError.unauthorized }
        guard (200..<300).contains(status) else { throw SeerrAPIError.badStatus(status) }
        return data
    }

    private static let queryValueAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")

    /// Keeps any base path (e.g. `https://host/seerr`) and points at its API root.
    private static func baseURL(from string: String) -> URL? {
        guard var components = ServiceURL.components(from: string) else { return nil }
        components.query = nil
        components.fragment = nil
        while components.path.hasSuffix("/") { components.path.removeLast() }
        components.path += "/api/v1"
        return components.url
    }

    private static func endpoint(_ baseURL: URL, _ path: String) -> URL {
        baseURL.appending(path: path)
    }
}

// MARK: - Response shapes

nonisolated private struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

nonisolated private struct ResultsPage: Decodable {
    let results: [Lossy<SeerrMediaItem>]

    var items: [SeerrMediaItem] { results.compactMap(\.value) }
}

nonisolated private struct CombinedCredits: Decodable {
    let cast: [Lossy<SeerrMediaItem>]
    let crew: [Lossy<SeerrMediaItem>]
}

nonisolated private struct DetailsResponse: Decodable {
    struct Genre: Decodable {
        let name: String
    }

    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let genres: [Genre]?
    let mediaInfo: SeerrMediaInfo?
    let seasons: [SeerrSeason]?
    let relatedVideos: [SeerrRelatedVideo]?
}
