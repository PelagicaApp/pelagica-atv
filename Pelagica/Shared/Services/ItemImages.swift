//
//  ItemImages.swift
//  Pelagica
//

import Foundation
import Get
import JellyfinAPI

/// Picks which image of an item to show and builds its URL, so every platform falls back the same way.
enum ItemImages {
    struct Source {
        let itemID: String
        let type: ImageType
        let tag: String?
    }

    static func primary(_ item: BaseItemDto) -> Source? {
        guard let id = item.id else { return nil }
        return Source(itemID: id, type: .primary, tag: item.imageTags?["Primary"])
    }

    /// Thumb, then backdrop, then the poster.
    static func landscape(_ item: BaseItemDto) -> Source? {
        guard let id = item.id else { return nil }
        if let thumbTag = item.imageTags?["Thumb"] {
            return Source(itemID: id, type: .thumb, tag: thumbTag)
        } else if let backdropTag = item.backdropImageTags?.first {
            return Source(itemID: id, type: .backdrop, tag: backdropTag)
        }
        return primary(item)
    }

    /// Series thumb or backdrop for episodes, nil when the item has none
    static func seriesLandscape(_ item: BaseItemDto) -> Source? {
        guard item.type == .episode else { return nil }
        if let seriesID = item.seriesID, let thumbTag = item.seriesThumbImageTag {
            return Source(itemID: seriesID, type: .thumb, tag: thumbTag)
        } else if let thumbItemID = item.parentThumbItemID, let thumbTag = item.parentThumbImageTag {
            return Source(itemID: thumbItemID, type: .thumb, tag: thumbTag)
        } else if let backdropItemID = item.parentBackdropItemID, let backdropTag = item.parentBackdropImageTags?.first {
            return Source(itemID: backdropItemID, type: .backdrop, tag: backdropTag)
        }
        return nil
    }

    static func backdrop(_ item: BaseItemDto) -> Source? {
        guard let id = item.id, let tag = item.backdropImageTags?.first else { return nil }
        return Source(itemID: id, type: .backdrop, tag: tag)
    }

    static func logo(_ item: BaseItemDto) -> Source? {
        guard let id = item.id, let tag = item.imageTags?["Logo"] else { return nil }
        return Source(itemID: id, type: .logo, tag: tag)
    }

    static func url(_ source: Source?, client: JellyfinClient?, width: Int, height: Int? = nil) -> URL? {
        guard let source, let client else { return nil }
        let request = Paths.getItemImage(
            itemID: source.itemID,
            imageType: source.type.rawValue,
            parameters: .init(fillWidth: width, fillHeight: height, tag: source.tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }
}
