//
//  GenreEntry.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

nonisolated struct GenreArtwork: Hashable {
    let itemID: String
    let imageType: ImageType
    let tag: String?

    init?(item: BaseItemDto) {
        guard let itemID = item.id else { return nil }
        self.itemID = itemID
        if let backdropTag = item.backdropImageTags?.first {
            imageType = .backdrop
            tag = backdropTag
        } else {
            imageType = .primary
            tag = item.imageTags?["Primary"]
        }
    }
}

nonisolated struct GenreEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let artwork: GenreArtwork?
    let totalItems: Int
}

nonisolated struct GenreRoute: Hashable {
    let id: String
    let name: String
}

extension GenreEntry {
    /// A stable color per genre, used to tint its card.
    var tint: Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        let hue = Double(hash % 360) / 360
        let saturation = 0.35 + Double((hash >> 16) % 10) / 100
        let lightness = 0.42 + Double((hash >> 32) % 8) / 100

        // HSL -> HSB
        let brightness = lightness + saturation * min(lightness, 1 - lightness)
        let hsbSaturation = brightness == 0 ? 0 : 2 * (1 - lightness / brightness)
        return Color(hue: hue, saturation: hsbSaturation, brightness: brightness)
    }
}
