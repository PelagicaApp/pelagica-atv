//
//  ItemActions.swift
//  Pelagica
//

import Get
import JellyfinAPI

enum ItemActions {
    static func setFavorite(_ isFavorite: Bool, itemID: String, client: JellyfinClient, userID: String?) async throws {
        _ = try await client.send(Paths.updateItemUserData(
            itemID: itemID,
            userID: userID,
            UpdateUserItemDataDto(isFavorite: isFavorite)
        ))
    }

    static func setWatchlist(_ isWatchlist: Bool, itemID: String, client: JellyfinClient, userID: String?) async throws {
        _ = try await client.send(Paths.updateItemUserData(
            itemID: itemID,
            userID: userID,
            UpdateUserItemDataDto(isLikes: isWatchlist)
        ))
    }

    static func setPlayed(_ isPlayed: Bool, itemID: String, client: JellyfinClient, userID: String?) async throws -> UserItemDataDto {
        try await client.send(isPlayed
            ? Paths.markPlayedItem(itemID: itemID, userID: userID)
            : Paths.markUnplayedItem(itemID: itemID, userID: userID)
        ).value
    }

    static func nextEpisode(seriesID: String, fields: [ItemFields]? = nil, client: JellyfinClient, userID: String?) async throws -> BaseItemDto? {
        let nextUp = try await client.send(Paths.getNextUp(parameters: .init(
            userID: userID,
            limit: 1,
            fields: fields,
            seriesID: seriesID
        ))).value
        if let episode = nextUp.items?.first {
            return episode
        }

        let episodes = try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: .init(
            userID: userID,
            fields: fields,
            limit: 1
        ))).value
        return episodes.items?.first
    }
}
