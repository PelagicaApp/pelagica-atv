//
//  PlaybackInfoDetails.swift
//  Pelagica
//

import Foundation
import JellyfinAPI

/// What the server decided for the current stream, for the playback info panel.
struct PlaybackInfoDetails {
    let playMethod: PlayMethod
    let mediaSource: MediaSourceInfo
    let playSessionID: String?
    let videoStream: MediaStream?
    let audioStream: MediaStream?
    let subtitleStream: MediaStream?
    let isSubtitleBurnedIn: Bool

    var transcodeReasons: [String] {
        guard
            playMethod == .transcode,
            let url = mediaSource.transcodingURL,
            let reasons = URLComponents(string: url)?.queryItems?
                .first(where: { $0.name.lowercased() == "transcodereasons" })?.value
        else { return [] }
        return reasons.split(separator: ",").map(String.init)
    }
}
