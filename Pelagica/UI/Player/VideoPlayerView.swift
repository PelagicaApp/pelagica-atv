//
//  VideoPlayerView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI
import UIKit

struct VideoPlayerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let item: BaseItemDto
    var startTicks: Int = 0

    @StateObject private var controller = VLCPlayerController()

    @State private var currentItem: BaseItemDto
    @State private var isLoaded = false
    @State private var playMethod: PlayMethod = .directPlay
    @State private var audioStreams: [MediaStream] = []
    @State private var selectedAudioStreamIndex: Int?
    @State private var subtitleStreams: [MediaStream] = []
    @State private var selectedSubtitleStreamIndex: Int?
    @State private var burnedInSubtitleStreamIndex: Int?
    @State private var activeItemID: String?
    @State private var currentMediaSourceID: String?
    @State private var currentPlaySessionID: String?
    @State private var didFallBackToTranscode = false
    @State private var didFailToResolve = false
    @State private var introRange: ClosedRange<TimeInterval>?
    @State private var outroRange: ClosedRange<TimeInterval>?

    init(item: BaseItemDto, startTicks: Int = 0) {
        self.item = item
        self.startTicks = startTicks
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCVideoSurface(view: controller.videoView)
                .ignoresSafeArea()

            if didFailToResolve {
                VStack(spacing: 24) {
                    Text(i18n.t("player:playbackDecodeErrorFailed"))
                        .font(.title2)
                        .foregroundStyle(.white)
                    Button(i18n.t("close")) { close() }
                }
            } else if isLoaded {
                PlayerControlsOverlay(
                    controller: controller,
                    title: playerTitle,
                    subtitle: playerSubtitle,
                    overview: currentItem.overview,
                    audioStreams: audioStreams,
                    selectedAudioIndex: selectedAudioStreamIndex,
                    subtitleStreams: subtitleStreams,
                    selectedSubtitleIndex: selectedSubtitleStreamIndex,
                    introRange: introRange,
                    outroRange: outroRange,
                    onSelectAudio: selectAudioTrack,
                    onSelectSubtitle: selectSubtitleTrack,
                    onClose: close
                )
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            controller.onProgress = reportProgress
            controller.onPlaybackEnded = handlePlaybackEnded
            controller.onPlaybackFailed = handlePlaybackFailed
        }
        .onDisappear {
            reportStopped(seconds: controller.currentSeconds)
            controller.stop()
        }
        .task(id: currentItem.id) {
            isLoaded = false
            didFailToResolve = false
            didFallBackToTranscode = false
            introRange = nil
            outroRange = nil
            selectedSubtitleStreamIndex = nil
            burnedInSubtitleStreamIndex = nil
            controller.setNowPlayingArtwork(nil)
            let ticks = currentItem.id == item.id ? startTicks : 0
            async let playback: Void = resolvePlayback(atTicks: ticks, applyServerDefaults: true)
            async let segments: Void = fetchSkippableSegments()
            async let artwork: Void = loadNowPlayingArtwork()
            _ = await (playback, segments, artwork)
        }
    }

    private var playerTitle: String {
        if currentItem.type == .episode, let seriesName = currentItem.seriesName {
            return seriesName
        }
        return currentItem.name ?? ""
    }

    private var playerSubtitle: String? {
        guard currentItem.type == .episode else { return nil }
        let season = currentItem.parentIndexNumber ?? 1
        let episode = currentItem.indexNumber ?? 1
        return "S\(season):E\(episode) \(currentItem.name ?? "")"
    }

    private var isTranscoded: Bool { playMethod == .transcode }

    private func close() {
        dismiss()
    }

    private func handlePlaybackEnded() {
        reportStopped(seconds: controller.currentSeconds)
        activeItemID = nil
        Task {
            if let next = await fetchNextEpisode() {
                currentItem = next
            } else {
                dismiss()
            }
        }
    }

    /// VLC can decode almost anything, so a direct-play failure usually means a broken file or an unreachable static stream.
    /// Give the server one chance to transcode before giving up.
    private func handlePlaybackFailed() {
        guard !isTranscoded, !didFallBackToTranscode else {
            didFailToResolve = true
            return
        }
        print("Pelagica playback: direct play failed, retrying with a server transcode")
        didFallBackToTranscode = true
        let ticks = Int(controller.currentSeconds * 10_000_000)
        Task {
            await resolvePlayback(
                atTicks: ticks,
                audioStreamIndex: selectedAudioStreamIndex,
                mediaSourceID: currentMediaSourceID
            )
        }
    }

    private func fetchNextEpisode() async -> BaseItemDto? {
        guard
            currentItem.type == .episode,
            let client = appState.client,
            let seriesID = currentItem.seriesID,
            let episodeID = currentItem.id
        else { return nil }

        do {
            let result = try await client.send(Paths.getEpisodes(
                seriesID: seriesID,
                parameters: .init(userID: appState.currentUser?.id, fields: [.overview], adjacentTo: episodeID, enableUserData: true)
            )).value
            guard
                let items = result.items,
                let currentIndex = items.firstIndex(where: { $0.id == episodeID })
            else { return nil }
            let nextIndex = items.index(after: currentIndex)
            guard nextIndex < items.endIndex else { return nil }
            return items[nextIndex]
        } catch {
            return nil
        }
    }

    // MARK: - Track selection

    private func selectAudioTrack(_ stream: MediaStream) {
        guard let index = stream.index, index != selectedAudioStreamIndex else { return }
        selectedAudioStreamIndex = index

        if isTranscoded {
            let ticks = Int(controller.currentSeconds * 10_000_000)
            Task { await resolvePlayback(atTicks: ticks, audioStreamIndex: index, mediaSourceID: currentMediaSourceID) }
        } else {
            controller.selectAudio(stream)
        }
    }

    private func selectSubtitleTrack(_ stream: MediaStream?) {
        guard stream?.index != selectedSubtitleStreamIndex else { return }
        selectedSubtitleStreamIndex = stream?.index

        let needsBurnIn = isTranscoded && stream.map(requiresBurnIn) == true
        if needsBurnIn || burnedInSubtitleStreamIndex != nil {
            let ticks = Int(controller.currentSeconds * 10_000_000)
            Task {
                await resolvePlayback(
                    atTicks: ticks,
                    audioStreamIndex: selectedAudioStreamIndex,
                    subtitleStreamIndex: needsBurnIn ? stream?.index : nil,
                    mediaSourceID: currentMediaSourceID
                )
            }
            return
        }
        controller.selectSubtitle(subtitleSelection(for: stream))
    }

    private func requiresBurnIn(_ stream: MediaStream) -> Bool {
        stream.isTextSubtitleStream == false
    }

    private func subtitleSelection(for stream: MediaStream?) -> VLCPlayerController.SubtitleSelection {
        guard let stream else { return .off }
        if stream.index == burnedInSubtitleStreamIndex {
            return .off
        }
        if !isTranscoded, stream.isExternal != true {
            return .embedded(stream)
        }
        guard let url = externalSubtitleURL(for: stream) else { return .off }
        return .external(stream, url)
    }

    private func externalSubtitleURL(for stream: MediaStream) -> URL? {
        guard let client = appState.client else { return nil }
        if let deliveryURL = stream.deliveryURL, stream.deliveryMethod == .external {
            return resolvedServerURL(path: deliveryURL, client: client)
        }
        guard let itemID = currentItem.id, let mediaSourceID = currentMediaSourceID, let index = stream.index else { return nil }
        let format = ["ass", "ssa"].contains(stream.codec?.lowercased() ?? "") ? "ass" : "srt"
        return resolvedServerURL(path: "/Videos/\(itemID)/\(mediaSourceID)/Subtitles/\(index)/0/Stream.\(format)", client: client)
    }

    // MARK: - Playback resolution

    private static let maxStreamingBitrate = 200_000_000

    private static let deviceProfile = DeviceProfile(
        directPlayProfiles: [
            DirectPlayProfile(
                container: [
                    "mkv", "webm", "mp4", "m4v", "mov", "avi", "divx", "xvid", "ts", "m2ts", "mts", "mpegts",
                    "mpg", "mpeg", "vob", "flv", "wmv", "asf", "3gp", "3g2", "ogv", "ogm", "ogg", "rm", "rmvb",
                    "dv", "mxf", "wtv", "nut", "f4v", "hls",
                ].joined(separator: ","),
                type: .video
            ),
            DirectPlayProfile(type: .audio),
        ],
        maxStaticBitrate: maxStreamingBitrate,
        maxStreamingBitrate: maxStreamingBitrate,
        subtitleProfiles: subtitleProfiles,
        transcodingProfiles: [
            TranscodingProfile(
                protocol: .hls,
                audioCodec: "aac,ac3,eac3,mp3,flac,opus",
                container: "ts",
                context: .streaming,
                maxAudioChannels: "8",
                minSegments: 1,
                type: .video,
                videoCodec: "hevc,h264"
            ),
        ]
    )

    private static let textSubtitleFormats = ["ass", "ssa", "srt", "subrip", "vtt", "webvtt", "sub", "smi", "ttml", "mov_text"]
    private static let imageSubtitleFormats = ["pgs", "pgssub", "dvdsub", "dvbsub", "vobsub", "xsub"]

    private static let subtitleProfiles: [SubtitleProfile] =
        (textSubtitleFormats + imageSubtitleFormats).map { SubtitleProfile(format: $0, method: .embed) }
        + textSubtitleFormats.map { SubtitleProfile(format: $0, method: .external) }
        + imageSubtitleFormats.map { SubtitleProfile(format: $0, method: .encode) }

    private func resolvePlayback(
        atTicks ticks: Int,
        audioStreamIndex: Int? = nil,
        subtitleStreamIndex: Int? = nil,
        mediaSourceID: String? = nil,
        applyServerDefaults: Bool = false
    ) async {
        guard let client = appState.client, let itemID = currentItem.id else {
            didFailToResolve = true
            return
        }

        let allowDirect = !didFallBackToTranscode
        do {
            let info = try await client.send(Paths.getPostedPlaybackInfo(
                itemID: itemID,
                parameters: .init(
                    userID: appState.currentUser?.id,
                    maxStreamingBitrate: Self.maxStreamingBitrate,
                    startTimeTicks: ticks,
                    audioStreamIndex: audioStreamIndex,
                    subtitleStreamIndex: subtitleStreamIndex,
                    mediaSourceID: mediaSourceID,
                    enableDirectPlay: allowDirect,
                    enableDirectStream: allowDirect,
                    enableTranscoding: true,
                    allowVideoStreamCopy: true,
                    allowAudioStreamCopy: true
                ),
                PlaybackInfoDto(
                    allowAudioStreamCopy: true,
                    allowVideoStreamCopy: true,
                    audioStreamIndex: audioStreamIndex,
                    deviceProfile: Self.deviceProfile,
                    enableDirectPlay: allowDirect,
                    enableDirectStream: allowDirect,
                    enableTranscoding: true,
                    maxStreamingBitrate: Self.maxStreamingBitrate,
                    mediaSourceID: mediaSourceID,
                    startTimeTicks: ticks,
                    subtitleStreamIndex: subtitleStreamIndex,
                    userID: appState.currentUser?.id
                )
            )).value
            guard let mediaSource = info.mediaSources?.first, let mediaSourceID = mediaSource.id else {
                print("Pelagica playback: no media source in PlaybackInfo response for item \(itemID)")
                didFailToResolve = true
                return
            }

            let url: URL?
            let method: PlayMethod
            if allowDirect, mediaSource.isSupportsDirectPlay == true || mediaSource.isSupportsDirectStream == true {
                let request = Paths.getVideoStream(itemID: itemID, parameters: .init(
                    container: mediaSource.container,
                    isStatic: true,
                    playSessionID: info.playSessionID,
                    mediaSourceID: mediaSourceID
                ))
                url = client.url(with: request, queryAPIKey: true)
                method = mediaSource.isSupportsDirectPlay == true ? .directPlay : .directStream
            } else if let transcodingPath = mediaSource.transcodingURL {
                url = resolvedServerURL(path: transcodingPath, client: client)
                method = .transcode
            } else {
                url = nil
                method = .transcode
            }

            guard let url else {
                print("""
                Pelagica playback: could not build a stream URL (container: \(mediaSource.container ?? "nil"), \
                supportsDirectPlay: \(String(describing: mediaSource.isSupportsDirectPlay)), \
                transcodingURL: \(mediaSource.transcodingURL ?? "nil"))
                """)
                didFailToResolve = true
                return
            }
            print("Pelagica playback: \(method.rawValue) via \(url.absoluteString)")

            let mediaStreams = mediaSource.mediaStreams ?? []
            audioStreams = mediaStreams.filter { $0.type == .audio }
            subtitleStreams = mediaStreams.filter { $0.type == .subtitle }
            selectedAudioStreamIndex = audioStreamIndex ?? mediaSource.defaultAudioStreamIndex ?? audioStreams.first?.index
            if applyServerDefaults {
                let defaultIndex = mediaSource.defaultSubtitleStreamIndex ?? -1
                selectedSubtitleStreamIndex = subtitleStreams.contains { $0.index == defaultIndex } ? defaultIndex : nil
            }

            activeItemID = itemID
            currentMediaSourceID = mediaSourceID
            currentPlaySessionID = info.playSessionID
            playMethod = method
            burnedInSubtitleStreamIndex = method == .transcode ? subtitleStreamIndex : nil

            var selectedSubtitle = subtitleStreams.first { $0.index == selectedSubtitleStreamIndex }
            if method == .transcode, applyServerDefaults, let stream = selectedSubtitle, requiresBurnIn(stream) {
                // A default image subtitle can't be attached to a transcode after the fact
                selectedSubtitle = nil
                selectedSubtitleStreamIndex = nil
            }

            controller.load(
                url: url,
                startSeconds: Double(ticks) / 10_000_000,
                knownDurationSeconds: currentItem.runTimeTicks.map { Double($0) / 10_000_000 },
                mediaStreams: method == .transcode ? [] : mediaStreams,
                audioStream: method == .transcode ? nil : audioStreams.first { $0.index == selectedAudioStreamIndex },
                subtitle: subtitleSelection(for: selectedSubtitle)
            )
            controller.setNowPlayingMetadata(title: playerTitle, subtitle: playerSubtitle, overview: currentItem.overview)
            isLoaded = true
            reportPlaybackStarted(positionTicks: ticks)
        } catch {
            print("Pelagica playback: PlaybackInfo request failed for item \(itemID): \(error)")
            didFailToResolve = true
        }
    }

    private func fetchSkippableSegments() async {
        guard let client = appState.client, let itemID = currentItem.id else { return }
        do {
            let result = try await client.send(Paths.getItemSegments(itemID: itemID, includeSegmentTypes: [.intro, .outro])).value
            for segment in result.items ?? [] {
                guard
                    let startTicks = segment.startTicks,
                    let endTicks = segment.endTicks,
                    endTicks > startTicks
                else { continue }
                let range = (Double(startTicks) / 10_000_000) ... (Double(endTicks) / 10_000_000)
                switch segment.type {
                case .intro: introRange = range
                case .outro: outroRange = range
                default: break
                }
            }
        } catch {
        }
    }

    private func loadNowPlayingArtwork() async {
        guard let client = appState.client, let id = currentItem.id else { return }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(fillWidth: 640, fillHeight: 960, tag: currentItem.imageTags?["Primary"])
        )
        guard let url = client.url(with: request, queryAPIKey: true) else { return }
        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let image = UIImage(data: data)
        else { return }
        controller.setNowPlayingArtwork(image)
    }

    private func resolvedServerURL(path: String, client: JellyfinClient) -> URL? {
        guard var components = URLComponents(string: path) else { return nil }
        let hasAPIKey = components.queryItems?.contains { $0.name.lowercased() == "api_key" } ?? false
        if !hasAPIKey, let token = client.accessToken {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "api_key", value: token)]
        }
        return components.url(relativeTo: client.configuration.url)?.absoluteURL
    }

    // MARK: - Playback reporting

    private func reportPlaybackStarted(positionTicks: Int) {
        guard let client = appState.client, let itemID = activeItemID, let mediaSourceID = currentMediaSourceID else { return }
        Task {
            _ = try? await client.send(Paths.reportPlaybackStart(PlaybackStateInfo(
                audioStreamIndex: selectedAudioStreamIndex,
                canSeek: true,
                isPaused: false,
                itemID: itemID,
                mediaSourceID: mediaSourceID,
                playMethod: playMethod,
                playSessionID: currentPlaySessionID,
                positionTicks: positionTicks,
                subtitleStreamIndex: selectedSubtitleStreamIndex
            )))
        }
    }

    private func reportProgress(seconds: TimeInterval, isPaused: Bool) {
        guard let client = appState.client, let itemID = activeItemID, let mediaSourceID = currentMediaSourceID else { return }
        let positionTicks = Int(seconds * 10_000_000)
        Task {
            _ = try? await client.send(Paths.reportPlaybackProgress(PlaybackStateInfo(
                audioStreamIndex: selectedAudioStreamIndex,
                canSeek: true,
                isPaused: isPaused,
                itemID: itemID,
                mediaSourceID: mediaSourceID,
                playMethod: playMethod,
                playSessionID: currentPlaySessionID,
                positionTicks: positionTicks,
                subtitleStreamIndex: selectedSubtitleStreamIndex
            )))
        }
    }

    private func reportStopped(seconds: TimeInterval) {
        guard let client = appState.client, let itemID = activeItemID, let mediaSourceID = currentMediaSourceID else { return }
        let positionTicks = Int(seconds * 10_000_000)
        Task {
            _ = try? await client.send(Paths.reportPlaybackStopped(PlaybackStopInfo(
                itemID: itemID,
                mediaSourceID: mediaSourceID,
                playSessionID: currentPlaySessionID,
                positionTicks: positionTicks
            )))
        }
    }
}

private struct VLCVideoSurface: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
