//
//  PlaybackInfoPanel.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

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

struct PlaybackInfoPanel: View {
    let controller: VLCPlayerController
    let details: PlaybackInfoDetails

    @State private var current: VLCPlayerController.Diagnostics?
    @State private var previous: VLCPlayerController.Diagnostics?

    private static let refreshInterval: Duration = .seconds(1)

    private struct Row: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    private struct Section: Identifiable {
        let title: String
        let rows: [Row]
        var id: String { title }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            column(serverSections)
            column(playerSections)
        }
        .padding(28)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .fixedSize()
        .task {
            while !Task.isCancelled {
                previous = current
                current = controller.diagnostics()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }

    private func column(_ sections: [Section]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title.uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                    ForEach(section.rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            Text(row.label)
                                .foregroundStyle(.white.opacity(0.65))
                                .frame(width: 150, alignment: .leading)
                            Text(row.value)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .frame(width: 330, alignment: .leading)
                        }
                        .font(.system(size: 17, weight: .medium).monospacedDigit())
                    }
                }
            }
        }
    }

    // MARK: Server side

    private var serverSections: [Section] {
        var sections = [playbackSection, sourceSection]
        if let video = details.videoStream { sections.append(videoSection(video)) }
        return sections
    }

    private var playbackSection: Section {
        var rows = [
            Row(label: "Method", value: details.playMethod.rawValue),
            Row(label: "Session", value: details.playSessionID ?? "–"),
            Row(label: "Stream", value: redactedStreamPath ?? "–"),
        ]
        let reasons = details.transcodeReasons
        if !reasons.isEmpty {
            rows.append(Row(label: "Reasons", value: reasons.joined(separator: ", ")))
        }
        if let container = details.mediaSource.transcodingContainer, details.playMethod == .transcode {
            let subProtocol = details.mediaSource.transcodingSubProtocol?.rawValue
            rows.append(Row(label: "Output", value: [container, subProtocol].compactMap { $0 }.joined(separator: " / ")))
        }
        return Section(title: "Playback", rows: rows)
    }

    private var sourceSection: Section {
        let source = details.mediaSource
        return Section(title: "Source", rows: [
            Row(label: "File", value: source.path.map { ($0 as NSString).lastPathComponent } ?? source.name ?? "–"),
            Row(label: "Container", value: source.container ?? "–"),
            Row(label: "Size", value: source.size.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "–"),
            Row(label: "Bitrate", value: Self.bitrate(source.bitrate)),
        ])
    }

    private func videoSection(_ video: MediaStream) -> Section {
        let resolution = both(video.width, video.height).map { "\($0)×\($1)" } ?? "–"
        let aspect = [video.aspectRatio, video.isAnamorphic == true ? "anamorphic" : nil].compactMap { $0 }.joined(separator: ", ")
        let color = [video.colorPrimaries, video.colorTransfer].compactMap { $0 }.joined(separator: " / ")
        return Section(title: "Video", rows: [
            Row(label: "Codec", value: Self.join(video.codec?.uppercased(), video.profile, video.level.map { "L\(Self.number($0))" })),
            Row(label: "Resolution", value: resolution),
            Row(label: "Frame rate", value: video.realFrameRate.map { "\(Self.number(Double($0))) fps" + (video.isInterlaced == true ? " (interlaced)" : "") } ?? "–"),
            Row(label: "Bitrate", value: Self.bitrate(video.bitRate)),
            Row(label: "Range", value: Self.join(video.videoRangeType?.rawValue, video.bitDepth.map { "\($0)-bit" }, video.pixelFormat)),
            Row(label: "Color", value: color.isEmpty ? "–" : color),
            Row(label: "Aspect", value: aspect.isEmpty ? "–" : aspect),
        ])
    }

    // MARK: Player side

    private var playerSections: [Section] {
        var sections: [Section] = []
        if let audio = details.audioStream { sections.append(audioSection(audio)) }
        sections.append(subtitleSection)
        sections.append(vlcSection)
        return sections
    }

    private func audioSection(_ audio: MediaStream) -> Section {
        Section(title: "Audio", rows: [
            Row(label: "Track", value: audio.displayTitle ?? audio.language ?? "–"),
            Row(label: "Codec", value: Self.join(audio.codec?.uppercased(), audio.profile)),
            Row(label: "Channels", value: Self.join(audio.channels.map(String.init), audio.channelLayout)),
            Row(label: "Sample rate", value: audio.sampleRate.map { "\(Self.number(Double($0) / 1000)) kHz" } ?? "–"),
            Row(label: "Bitrate", value: Self.bitrate(audio.bitRate)),
        ])
    }

    private var subtitleSection: Section {
        guard let subtitle = details.subtitleStream else {
            return Section(title: "Subtitles", rows: [Row(label: "Track", value: "Off")])
        }
        let delivery = details.isSubtitleBurnedIn
            ? "burned in"
            : subtitle.isExternal == true ? "external" : "embedded"
        return Section(title: "Subtitles", rows: [
            Row(label: "Track", value: subtitle.displayTitle ?? subtitle.language ?? "–"),
            Row(label: "Format", value: Self.join(subtitle.codec?.uppercased(), delivery, subtitle.isForced == true ? "forced" : nil)),
        ])
    }

    private var vlcSection: Section {
        guard let current else {
            return Section(title: "VLC", rows: [Row(label: "State", value: "–")])
        }
        let elapsed = previous.map { current.date.timeIntervalSince($0.date) } ?? 0
        // The byte counter is a 32-bit int in VLCKit and wraps on long sessions, so a negative delta is skipped.
        let readRate: String = {
            guard let previous, elapsed > 0, current.readBytes >= previous.readBytes else { return "–" }
            return Self.bitrate(Int(Double(current.readBytes - previous.readBytes) * 8 / elapsed))
        }()
        let fps: String = {
            guard let previous, elapsed > 0, current.displayedPictures >= previous.displayedPictures else { return "–" }
            return "\(Self.number(Double(current.displayedPictures - previous.displayedPictures) / elapsed)) fps"
        }()
        let output = current.videoSize == .zero
            ? "–"
            : "\(Int(current.videoSize.width))×\(Int(current.videoSize.height))" + (current.hasVideoOut ? "" : " (no vout)")

        return Section(title: "VLC", rows: [
            Row(label: "State", value: current.state + (current.rate != 1 ? " @ \(Self.number(Double(current.rate)))×" : "")),
            Row(label: "Position", value: "\(ScrubberBar.format(controller.currentSeconds)) / \(ScrubberBar.format(controller.durationSeconds))"),
            Row(label: "Video out", value: output),
            Row(label: "Aspect", value: controller.aspectRatioOverride.map { "forced \($0)" } ?? "auto"),
            Row(label: "Display", value: fps),
            Row(label: "Network", value: readRate),
            Row(label: "Read", value: ByteCountFormatter.string(fromByteCount: Int64(current.readBytes), countStyle: .file)),
            Row(label: "Cache", value: "\(VLCPlayerController.networkCachingMilliseconds) ms"),
            Row(label: "Frames", value: "\(current.displayedPictures) shown, \(current.lostPictures) dropped"),
            Row(label: "Audio bufs", value: "\(current.playedAudioBuffers) played, \(current.lostAudioBuffers) lost"),
            Row(label: "Demux", value: "\(current.demuxCorrupted) corrupt, \(current.demuxDiscontinuities) discont."),
            Row(label: "Track IDs", value: "audio \(current.audioTrackID), sub \(current.subtitleTrackID)"),
        ])
    }

    // MARK: Formatting

    /// The stream URL without its API key, so the panel is safe to screenshot
    private var redactedStreamPath: String? {
        guard let url = current?.streamURL, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = components.queryItems?.filter { !["api_key", "apikey"].contains($0.name.lowercased()) }
        components.scheme = nil
        components.host = nil
        components.port = nil
        return components.string
    }

    private static func bitrate(_ bitsPerSecond: Int?) -> String {
        guard let bitsPerSecond, bitsPerSecond > 0 else { return "–" }
        if bitsPerSecond >= 1_000_000 {
            return "\(number(Double(bitsPerSecond) / 1_000_000)) Mbps"
        }
        return "\(bitsPerSecond / 1000) kbps"
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func join(_ parts: String?...) -> String {
        let joined = parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return joined.isEmpty ? "–" : joined
    }
}

private func both<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
