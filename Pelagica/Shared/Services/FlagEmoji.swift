//
//  FlagEmoji.swift
//  Pelagica
//

import Foundation

extension String {
    /// The flag for a two-letter country code, nil for anything else.
    var flagEmoji: String? {
        let scalars = uppercased().unicodeScalars
        guard scalars.count == 2, scalars.allSatisfy({ ("A"..."Z").contains($0) }) else { return nil }
        return String(String.UnicodeScalarView(scalars.compactMap { UnicodeScalar(127397 + $0.value) }))
    }
}
