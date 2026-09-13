//
//  CollectionSorting.swift
//  Pelagica
//

import Foundation
import JellyfinAPI

enum CollectionSorting {
    static func sort(_ items: [BaseItemDto], by option: CollectionSortOption) -> [BaseItemDto] {
        if option == .random {
            return items.shuffled()
        }

        let ascending = option != .premiereDateDesc
        return items.sorted { lhs, rhs in
            let timeA = releaseDate(for: lhs)
            let timeB = releaseDate(for: rhs)
            switch (timeA, timeB) {
            case (nil, nil):
                return false
            case (nil, _):
                return false
            case (_, nil):
                return true
            case let (a?, b?):
                return ascending ? a < b : a > b
            }
        }
    }

    private static func releaseDate(for item: BaseItemDto) -> Date? {
        if let date = item.premiereDate { return date }
        if let year = item.productionYear {
            return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 1, day: 1))
        }
        return nil
    }
}
