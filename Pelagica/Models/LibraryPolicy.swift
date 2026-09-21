import JellyfinAPI

nonisolated enum LibraryPolicy {
    static func isLibrary(_ item: BaseItemDto) -> Bool {
        guard let id = item.id, !id.isEmpty else { return false }
        return item.collectionType != nil || isLibraryFolder(item)
    }

    private static func isLibraryFolder(_ item: BaseItemDto) -> Bool {
        switch item.type {
        case .collectionFolder, .userView, .aggregateFolder, .userRootFolder,
             .folder, .basePluginFolder, .playlistsFolder, .manualPlaylistsFolder:
            return true
        case nil:
            return item.isFolder == true
        default:
            return false
        }
    }

    static func isContainer(_ item: BaseItemDto) -> Bool {
        if isLibraryFolder(item) { return true }
        switch item.type {
        case .boxSet, .photoAlbum, .playlist, .musicAlbum, .musicArtist, .season:
            return true
        default:
            return false
        }
    }

    static func recentItemTypes(for type: CollectionType?) -> [BaseItemKind]? {
        switch type {
        case .movies: return [.movie]
        case .tvshows: return [.series]
        case .music: return [.musicAlbum, .audio, .audioBook]
        case .musicvideos: return [.musicVideo, .video]
        case .trailers: return [.trailer]
        case .homevideos: return [.video]
        case .boxsets: return [.boxSet]
        case .books: return [.book, .audioBook]
        case .photos: return [.photo, .photoAlbum]
        case .livetv: return [.liveTvChannel, .tvChannel]
        case .playlists: return [.playlist]
        case .unknown, .folders, nil:
            // Mixed responses normalize to unknown; keep their media kinds unrestricted.
            return nil
        }
    }

    static func canPlayVideo(_ item: BaseItemDto) -> Bool {
        guard let id = item.id, !id.isEmpty, !isContainer(item) else { return false }
        switch item.type {
        case .movie, .episode, .video, .musicVideo, .trailer, .recording:
            return true
        default:
            return false
        }
    }
}
