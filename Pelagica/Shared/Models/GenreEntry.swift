//
//  GenreEntry.swift
//  Pelagica
//

import JellyfinAPI

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
