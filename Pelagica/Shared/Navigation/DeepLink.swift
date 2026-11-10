//
//  DeepLink.swift
//  Pelagica
//

import Foundation

/// A `pelagica://` link. The supported forms are documented in DEEPLINKS.md.
enum DeepLink: Hashable {
    case tab(MainTab)
    case search(String)
    case item(id: String)
    case play(id: String)
    case person(id: String)
    case library(id: String)
    case seerr(SeerrMediaType, tmdbID: Int)

    static let scheme = "pelagica"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host()?.lowercased() else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let parts = url.pathComponents.filter { $0 != "/" }
        let first = parts.first

        switch (host, parts.count) {
        case ("home", 0):
            self = .tab(.home)
        case ("library", 0), ("libraries", 0):
            self = .tab(.library)
        case ("settings", 0):
            self = .tab(.settings)
        case ("search", 0):
            let query = components?.queryItems?.first { $0.name == "q" }?.value ?? ""
            self = query.isEmpty ? .tab(.search) : .search(query)
        case ("item", 1):
            self = .item(id: first!)
        case ("play", 1):
            self = .play(id: first!)
        case ("person", 1):
            self = .person(id: first!)
        case ("library", 1):
            self = .library(id: first!)
        case ("seerr", 2):
            guard let type = SeerrMediaType(rawValue: parts[0].lowercased()),
                  let tmdbID = Int(parts[1]) else { return nil }
            self = .seerr(type, tmdbID: tmdbID)
        default:
            return nil
        }
    }
}
