//
//  SeerrItemRoute.swift
//  Pelagica
//

import JellyfinAPI

struct SeerrItemRoute: Hashable {
    let tmdbID: Int
    let mediaType: SeerrMediaType
    var title: String?
}

extension SeerrMediaItem {
    /// Fully available items open their library page. Anything else opens the Seerr page.
    var libraryRoute: ItemDetailRoute? {
        guard status == .available, let jellyfinID = mediaInfo?.jellyfinMediaId else { return nil }
        return ItemDetailRoute(item: BaseItemDto(id: jellyfinID, name: title))
    }

    var seerrRoute: SeerrItemRoute {
        SeerrItemRoute(tmdbID: tmdbID, mediaType: mediaType, title: title)
    }
}
