//
//  TrackPreferences.swift
//  Pelagica
//

import Foundation
import JellyfinAPI

struct TrackPreferences {
    enum SubtitleChoice: Equatable {
        case off
        case stream(Int)
    }

    struct Resolved {
        var audioIndex: Int?
        var subtitle: SubtitleChoice?
    }

    private struct StoredTrack: Codable {
        var itemID: String
        var index: Int
        var language: String?
        var title: String?
        var isForced: Bool
        var isHearingImpaired: Bool
    }

    private struct StoredTracks: Codable {
        var audio: StoredTrack?
        var subtitle: StoredTrack?
        var subtitlesOff = false
    }

    private static let defaultsKeyPrefix = "trackPreferences."

    private let defaults = UserDefaults.standard
    private let userID: String

    init?(userID: String?) {
        guard let userID else { return nil }
        self.userID = userID
    }

    // MARK: - Reading

    func resolve(for item: BaseItemDto, audioStreams: [MediaStream], subtitleStreams: [MediaStream]) -> Resolved {
        guard let itemID = item.id, let scopeID = Self.scopeID(for: item), let stored = load()[scopeID] else { return Resolved() }

        let audioIndex = stored.audio.flatMap { Self.bestMatch(for: $0, itemID: itemID, in: audioStreams)?.index }
        let subtitle: SubtitleChoice? = if stored.subtitlesOff {
            .off
        } else {
            stored.subtitle.flatMap { Self.bestMatch(for: $0, itemID: itemID, in: subtitleStreams)?.index }.map(SubtitleChoice.stream)
        }
        return Resolved(audioIndex: audioIndex, subtitle: subtitle)
    }

    // MARK: - Writing

    func rememberAudio(_ stream: MediaStream, for item: BaseItemDto) {
        guard let track = Self.storedTrack(for: stream, item: item) else { return }
        update(for: item) { $0.audio = track }
    }

    func rememberSubtitle(_ stream: MediaStream?, for item: BaseItemDto) {
        guard let stream else {
            update(for: item) {
                $0.subtitle = nil
                $0.subtitlesOff = true
            }
            return
        }
        guard let track = Self.storedTrack(for: stream, item: item) else { return }
        update(for: item) {
            $0.subtitle = track
            $0.subtitlesOff = false
        }
    }

    // MARK: - Matching

    private static func bestMatch(for track: StoredTrack, itemID: String, in streams: [MediaStream]) -> MediaStream? {
        // Same file: the index is reliable as long as the stream still looks the same
        if track.itemID == itemID,
           let stream = streams.first(where: { $0.index == track.index && normalizedLanguage($0.language) == track.language }) {
            return stream
        }

        guard let language = track.language else { return nil }
        var best: (stream: MediaStream, score: Int)?
        for stream in streams where normalizedLanguage(stream.language) == language {
            var score = 0
            if (stream.isForced ?? false) == track.isForced { score += 4 }
            if (stream.isHearingImpaired ?? false) == track.isHearingImpaired { score += 2 }
            if track.title != nil, stream.title == track.title { score += 1 }
            if score > (best?.score ?? -1) {
                best = (stream, score)
            }
        }
        return best?.stream
    }

    private static func normalizedLanguage(_ language: String?) -> String? {
        guard let language = language?.lowercased(), !language.isEmpty, language != "und" else { return nil }
        return language
    }

    private static func storedTrack(for stream: MediaStream, item: BaseItemDto) -> StoredTrack? {
        guard let itemID = item.id, let index = stream.index else { return nil }
        return StoredTrack(
            itemID: itemID,
            index: index,
            language: normalizedLanguage(stream.language),
            title: stream.title,
            isForced: stream.isForced ?? false,
            isHearingImpaired: stream.isHearingImpaired ?? false
        )
    }

    private static func scopeID(for item: BaseItemDto) -> String? {
        item.type == .episode ? (item.seriesID ?? item.id) : item.id
    }

    // MARK: - Storage

    private var defaultsKey: String { Self.defaultsKeyPrefix + userID }

    private func load() -> [String: StoredTracks] {
        guard let data = defaults.data(forKey: defaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: StoredTracks].self, from: data)) ?? [:]
    }

    private func update(for item: BaseItemDto, _ change: (inout StoredTracks) -> Void) {
        guard let scopeID = Self.scopeID(for: item) else { return }
        var all = load()
        var tracks = all[scopeID] ?? StoredTracks()
        change(&tracks)
        all[scopeID] = tracks
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
