//
//  StudioEntry.swift
//  Pelagica
//

import Foundation
import Get
import JellyfinAPI

nonisolated struct StudioEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int
}

nonisolated struct StudioRoute: Hashable {
    let id: String
    let name: String
}

nonisolated struct StudiosRoute: Hashable {}

nonisolated enum StudiosAPI {
    private static let pageSize = 300

    static func fetchStudiosByItemCount(client: JellyfinClient, userID: String) async -> [StudioEntry] {
        var counts: [String: StudioEntry] = [:]
        var startIndex = 0

        while true {
            let items: [BaseItemDto]
            do {
                items = try await client.send(Paths.getItems(parameters: .init(
                    userID: userID,
                    startIndex: startIndex,
                    limit: pageSize,
                    isRecursive: true,
                    fields: [.studios],
                    includeItemTypes: [.movie, .series],
                    enableImages: false
                ))).value.items ?? []
            } catch {
                break
            }

            for item in items {
                for studio in item.studios ?? [] {
                    guard let id = studio.id, let name = studio.name else { continue }
                    let count = (counts[id]?.count ?? 0) + 1
                    counts[id] = StudioEntry(id: id, name: name, count: count)
                }
            }

            startIndex += items.count
            if items.count < pageSize { break }
        }

        return counts.values.sorted { lhs, rhs in
            lhs.count != rhs.count ? lhs.count > rhs.count : lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }
}
