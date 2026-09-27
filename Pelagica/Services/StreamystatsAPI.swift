//
//  StreamystatsAPI.swift
//  Pelagica
//

import Foundation
import Get
import JellyfinAPI

nonisolated struct StreamystatsRecommendation {
    let item: BaseItemDto
    let similarity: Double
    let basedOn: [String]
}

nonisolated enum StreamystatsAPI {
    private struct Response: Decodable {
        let data: [Entry]
    }

    private struct Entry: Decodable {
        let item: MediaItem
        let similarity: Double
        let basedOn: [MediaItem]?
    }

    private struct MediaItem: Decodable {
        let id: String
        let name: String?
    }

    private static func baseURLComponents(from string: String) -> URLComponents? {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = value.firstMatch(of: #/^(https?):/*/#.ignoresCase()) {
            value = "\(match.1.lowercased())://" + value[match.range.upperBound...]
        } else if !value.contains("://") {
            value = "https://" + value
        }
        guard let components = URLComponents(string: value), components.host?.isEmpty == false else { return nil }
        return components
    }

    /// Fetches recommendations from Streamystats and resolves them to full Jellyfin items, keeping Streamystats' order.
    static func fetchRecommendations(
        streamystatsURL: String,
        type: RecommendationType?,
        limit: Int,
        client: JellyfinClient,
        userID: String
    ) async -> [StreamystatsRecommendation] {
        guard
            let token = client.accessToken,
            let serverHost = client.configuration.url.host(),
            var components = baseURLComponents(from: streamystatsURL)
        else { return [] }

        components.path = "/api/recommendations"
        components.queryItems = [
            URLQueryItem(name: "serverUrl", value: serverHost),
            URLQueryItem(name: "format", value: "full"),
            URLQueryItem(name: "type", value: (type ?? .all).rawValue),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MediaBrowser Token=\"\(token)\"", forHTTPHeaderField: "Authorization")

        let entries: [Entry]
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            entries = try JSONDecoder().decode(Response.self, from: data).data
        } catch {
            return []
        }
        guard !entries.isEmpty else { return [] }

        let items: [BaseItemDto]
        do {
            items = try await client.send(Paths.getItems(parameters: .init(
                userID: userID,
                fields: [.overview, .genres],
                enableUserData: true,
                ids: entries.map(\.item.id)
            ))).value.items ?? []
        } catch {
            return []
        }

        let itemsByID = Dictionary(items.compactMap { item in item.id.map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        return entries.compactMap { entry in
            guard let item = itemsByID[entry.item.id] else { return nil }
            return StreamystatsRecommendation(
                item: item,
                similarity: entry.similarity,
                basedOn: (entry.basedOn ?? []).compactMap(\.name)
            )
        }
    }
}
