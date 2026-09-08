//
//  VideoPlayerView.swift
//  Pelagica
//

import AVKit
import CoreMedia
import Get
import JellyfinAPI
import SwiftUI
import UIKit

struct VideoPlayerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let item: BaseItemDto
    var startTicks: Int = 0

    @State private var streamURL: URL?
    @State private var startTimeSeconds: Double = 0
    @State private var isTranscoded = false
    @State private var audioStreams: [MediaStream] = []
    @State private var selectedAudioStreamIndex: Int?
    @State private var currentMediaSourceID: String?
    @State private var currentPlaySessionID: String?
    @State private var didFailToResolve = false
    @State private var introRange: ClosedRange<TimeInterval>?
    @State private var outroRange: ClosedRange<TimeInterval>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let streamURL {
                AVPlayerControllerView(
                    url: streamURL,
                    startTimeSeconds: startTimeSeconds,
                    title: playerTitle,
                    subtitle: playerSubtitle,
                    overview: item.overview,
                    audioStreams: audioStreams,
                    selectedAudioStreamIndex: selectedAudioStreamIndex,
                    isTranscoded: isTranscoded,
                    introRange: introRange,
                    outroRange: outroRange,
                    onAudioTrackSelected: switchAudioTrack,
                    onProgress: reportProgress,
                    onStopped: reportStopped
                )
                // An audio-track switch on transcoded content resolves a new stream URL; forcing
                // view identity on it makes SwiftUI tear down and recreate the player instead of
                // trying to mutate one in place.
                .id(streamURL)
                .ignoresSafeArea()
            } else if didFailToResolve {
                VStack(spacing: 24) {
                    Text("Couldn't play this item")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Button("Close") { dismiss() }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            async let playback: Void = resolvePlayback(atTicks: startTicks)
            async let intro: Void = fetchSkippableSegments()
            _ = await (playback, intro)
        }
    }

    private var playerTitle: String {
        if item.type == .episode, let seriesName = item.seriesName {
            return seriesName
        }
        return item.name ?? ""
    }

    private var playerSubtitle: String? {
        guard item.type == .episode else { return nil }
        let season = item.parentIndexNumber ?? 1
        let episode = item.indexNumber ?? 1
        return "S\(season):E\(episode) \(item.name ?? "")"
    }

    private func switchAudioTrack(to streamIndex: Int, atSeconds seconds: TimeInterval) {
        let ticks = Int(seconds * 10_000_000)
        Task { await resolvePlayback(atTicks: ticks, audioStreamIndex: streamIndex, mediaSourceID: currentMediaSourceID) }
    }

    // MARK: - Playback resolution

    private static let deviceProfile = DeviceProfile(
        directPlayProfiles: [
            DirectPlayProfile(
                audioCodec: "aac,ac3,eac3,mp3,flac,opus",
                container: "mp4,m4v,mov",
                type: .video,
                videoCodec: "h264,hevc"
            ),
        ],
        transcodingProfiles: [
            TranscodingProfile(
                protocol: .hls,
                audioCodec: "aac",
                container: "ts",
                context: .streaming,
                maxAudioChannels: "6",
                minSegments: 1,
                type: .video,
                videoCodec: "h264"
            ),
        ]
    )

    private func resolvePlayback(atTicks ticks: Int, audioStreamIndex: Int? = nil, mediaSourceID: String? = nil) async {
        guard let client = appState.client, let itemID = item.id else {
            didFailToResolve = true
            return
        }

        do {
            let info = try await client.send(Paths.getPostedPlaybackInfo(
                itemID: itemID,
                parameters: .init(
                    userID: appState.currentUser?.id,
                    startTimeTicks: ticks,
                    audioStreamIndex: audioStreamIndex,
                    mediaSourceID: mediaSourceID
                ),
                PlaybackInfoDto(
                    audioStreamIndex: audioStreamIndex,
                    deviceProfile: Self.deviceProfile,
                    mediaSourceID: mediaSourceID,
                    startTimeTicks: ticks,
                    userID: appState.currentUser?.id
                )
            )).value
            guard let mediaSource = info.mediaSources?.first, let mediaSourceID = mediaSource.id else {
                print("Pelagica playback: no media source in PlaybackInfo response for item \(itemID)")
                didFailToResolve = true
                return
            }

            let url: URL?
            let transcoded: Bool
            if mediaSource.isSupportsDirectPlay == true {
                let request = Paths.getVideoStream(itemID: itemID, parameters: .init(
                    container: mediaSource.container,
                    isStatic: true,
                    playSessionID: info.playSessionID,
                    mediaSourceID: mediaSourceID
                ))
                url = client.url(with: request, queryAPIKey: true)
                startTimeSeconds = Double(ticks) / 10_000_000
                transcoded = false
            } else if let transcodingPath = mediaSource.transcodingURL {
                url = resolvedTranscodingURL(path: transcodingPath, client: client)
                startTimeSeconds = Double(ticks) / 10_000_000
                transcoded = true
            } else {
                url = nil
                transcoded = false
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
            print("Pelagica playback: resolved stream URL: \(url.absoluteString)")

            let streams = mediaSource.mediaStreams?.filter { $0.type == .audio } ?? []
            print("""
            Pelagica playback: mediaStreams total: \(mediaSource.mediaStreams?.count ?? -1), \
            audio streams: \(streams.count) — \
            \(streams.map { "[index: \($0.index.map(String.init) ?? "nil"), title: \($0.displayTitle ?? "nil"), language: \($0.language ?? "nil")]" }.joined(separator: ", "))
            """)
            audioStreams = streams
            selectedAudioStreamIndex = audioStreamIndex ?? mediaSource.defaultAudioStreamIndex ?? streams.first?.index
            currentMediaSourceID = mediaSourceID
            currentPlaySessionID = info.playSessionID
            isTranscoded = transcoded
            streamURL = url
            reportPlaybackStarted(positionTicks: ticks)
        } catch {
            print("Pelagica playback: PlaybackInfo request failed for item \(itemID): \(error)")
            didFailToResolve = true
        }
    }

    private func fetchSkippableSegments() async {
        guard let client = appState.client, let itemID = item.id else { return }
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

    private func resolvedTranscodingURL(path: String, client: JellyfinClient) -> URL? {
        guard var components = URLComponents(string: path) else { return nil }
        let hasAPIKey = components.queryItems?.contains { $0.name.lowercased() == "api_key" } ?? false
        if !hasAPIKey, let token = client.accessToken {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "api_key", value: token)]
        }
        return components.url(relativeTo: client.configuration.url)?.absoluteURL
    }

    // MARK: - Playback reporting

    private func reportPlaybackStarted(positionTicks: Int) {
        guard let client = appState.client, let itemID = item.id, let mediaSourceID = currentMediaSourceID else { return }
        Task {
            _ = try? await client.send(Paths.reportPlaybackStart(PlaybackStateInfo(
                audioStreamIndex: selectedAudioStreamIndex,
                canSeek: true,
                isPaused: false,
                itemID: itemID,
                mediaSourceID: mediaSourceID,
                playMethod: isTranscoded ? .transcode : .directPlay,
                playSessionID: currentPlaySessionID,
                positionTicks: positionTicks
            )))
        }
    }

    private func reportProgress(seconds: TimeInterval, isPaused: Bool) {
        guard let client = appState.client, let itemID = item.id, let mediaSourceID = currentMediaSourceID else { return }
        let positionTicks = Int(seconds * 10_000_000)
        Task {
            _ = try? await client.send(Paths.reportPlaybackProgress(PlaybackStateInfo(
                audioStreamIndex: selectedAudioStreamIndex,
                canSeek: true,
                isPaused: isPaused,
                itemID: itemID,
                mediaSourceID: mediaSourceID,
                playMethod: isTranscoded ? .transcode : .directPlay,
                playSessionID: currentPlaySessionID,
                positionTicks: positionTicks
            )))
        }
    }

    private func reportStopped(seconds: TimeInterval) {
        guard let client = appState.client, let itemID = item.id, let mediaSourceID = currentMediaSourceID else { return }
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

private struct AVPlayerControllerView: UIViewControllerRepresentable {
    let url: URL
    let startTimeSeconds: Double
    let title: String
    var subtitle: String?
    var overview: String?
    let audioStreams: [MediaStream]
    let selectedAudioStreamIndex: Int?
    let isTranscoded: Bool
    let introRange: ClosedRange<TimeInterval>?
    let outroRange: ClosedRange<TimeInterval>?
    let onAudioTrackSelected: (Int, TimeInterval) -> Void
    let onProgress: (TimeInterval, Bool) -> Void
    let onStopped: (TimeInterval) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        item.externalMetadata = metadataItems()
        context.coordinator.observe(item)

        let player = AVPlayer(playerItem: item)
        if startTimeSeconds > 0 {
            player.seek(to: CMTime(seconds: startTimeSeconds, preferredTimescale: 1))
        }
        context.coordinator.configureReporting(onProgress: onProgress, onStopped: onStopped, player: player)

        let controller = AVPlayerViewController()
        controller.player = player
        context.coordinator.configureAudioMenu(
            streams: audioStreams,
            selectedIndex: selectedAudioStreamIndex,
            isTranscoded: isTranscoded,
            onAudioTrackSelected: onAudioTrackSelected,
            controller: controller
        )
        context.coordinator.configureSkippableSegments(intro: introRange, outro: outroRange, controller: controller)
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        context.coordinator.configureAudioMenu(
            streams: audioStreams,
            selectedIndex: selectedAudioStreamIndex,
            isTranscoded: isTranscoded,
            onAudioTrackSelected: onAudioTrackSelected,
            controller: uiViewController
        )
        context.coordinator.configureSkippableSegments(intro: introRange, outro: outroRange, controller: uiViewController)
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.reportStopped()
        uiViewController.player?.pause()
        uiViewController.player = nil
    }

    private func metadataItems() -> [AVMetadataItem] {
        var items = [makeMetadataItem(identifier: .commonIdentifierTitle, value: title)]
        if let subtitle {
            items.append(makeMetadataItem(identifier: .iTunesMetadataTrackSubTitle, value: subtitle))
        }
        if let overview {
            items.append(makeMetadataItem(identifier: .commonIdentifierDescription, value: overview))
        }
        return items
    }

    private func makeMetadataItem(identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    final class Coordinator: NSObject {
        private weak var controller: AVPlayerViewController?
        private var audioStreams: [MediaStream] = []
        private var currentAudioIndex: Int?
        private var isTranscoded = false
        private var onAudioTrackSelected: ((Int, TimeInterval) -> Void)?

        private var statusObservation: NSKeyValueObservation?
        private var errorLogObserver: NSObjectProtocol?

        private weak var reportedPlayer: AVPlayer?
        private var progressObserverToken: Any?
        private var onStopped: ((TimeInterval) -> Void)?

        private enum SkipSegmentKind {
            case intro
            case outro

            var title: String {
                switch self {
                case .intro: return "Skip Intro"
                case .outro: return "Skip Outro"
                }
            }
        }

        private var introRange: ClosedRange<TimeInterval>?
        private var outroRange: ClosedRange<TimeInterval>?
        private weak var introObservedPlayer: AVPlayer?
        private var introTimeObserverToken: Any?
        private var visibleSkipSegment: SkipSegmentKind?

        func observe(_ item: AVPlayerItem) {
            statusObservation = item.observe(\.status, options: [.new]) { item, _ in
                guard item.status == .failed else { return }
                print("Pelagica playback: AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown") \(String(describing: item.error))")
            }

            errorLogObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.newErrorLogEntryNotification,
                object: item,
                queue: .main
            ) { notification in
                guard
                    let item = notification.object as? AVPlayerItem,
                    let entry = item.errorLog()?.events.last
                else { return }
                print("""
                Pelagica playback: HLS error log — status: \(entry.errorStatusCode), \
                domain: \(entry.errorDomain), comment: \(entry.errorComment ?? "nil"), \
                uri: \(entry.uri ?? "nil")
                """)
            }
        }

        // MARK: Playback reporting

        func configureReporting(onProgress: @escaping (TimeInterval, Bool) -> Void, onStopped: @escaping (TimeInterval) -> Void, player: AVPlayer) {
            self.onStopped = onStopped
            reportedPlayer = player
            guard progressObserverToken == nil else { return }
            let interval = CMTime(seconds: 10, preferredTimescale: 1)
            progressObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
                guard let player else { return }
                onProgress(time.seconds, player.rate == 0)
            }
        }

        func reportStopped() {
            if let seconds = reportedPlayer?.currentTime().seconds, seconds.isFinite {
                onStopped?(seconds)
            }
            if let progressObserverToken, let reportedPlayer {
                reportedPlayer.removeTimeObserver(progressObserverToken)
            }
            progressObserverToken = nil
            removeIntroObserver()
        }

        // MARK: Intro / outro skip

        func configureSkippableSegments(
            intro: ClosedRange<TimeInterval>?,
            outro: ClosedRange<TimeInterval>?,
            controller: AVPlayerViewController
        ) {
            self.controller = controller
            guard introRange != intro || outroRange != outro else { return }
            introRange = intro
            outroRange = outro
            removeIntroObserver()

            guard (intro != nil || outro != nil), let player = controller.player else {
                controller.contextualActions = []
                return
            }

            introObservedPlayer = player
            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
            introTimeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                self?.updateSkipActionVisibility(currentSeconds: time.seconds, intro: intro, outro: outro)
            }
        }

        private func updateSkipActionVisibility(currentSeconds: Double, intro: ClosedRange<TimeInterval>?, outro: ClosedRange<TimeInterval>?) {
            guard let controller else { return }

            let active: (kind: SkipSegmentKind, seekTo: TimeInterval)?
            if let intro, intro.contains(currentSeconds) {
                active = (.intro, intro.upperBound)
            } else if let outro, outro.contains(currentSeconds) {
                active = (.outro, outro.upperBound)
            } else {
                active = nil
            }

            guard active?.kind != visibleSkipSegment else { return }
            visibleSkipSegment = active?.kind
            controller.contextualActions = active.map { [makeSkipAction(kind: $0.kind, seekingTo: $0.seekTo)] } ?? []
        }

        private func makeSkipAction(kind: SkipSegmentKind, seekingTo seconds: TimeInterval) -> UIAction {
            UIAction(title: kind.title, image: UIImage(systemName: "forward.fill")) { [weak self] _ in
                guard let self else { return }
                self.controller?.player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
                self.visibleSkipSegment = nil
                self.controller?.contextualActions = []
            }
        }

        private func removeIntroObserver() {
            if let introTimeObserverToken, let introObservedPlayer {
                introObservedPlayer.removeTimeObserver(introTimeObserverToken)
            }
            introTimeObserverToken = nil
            introObservedPlayer = nil
            visibleSkipSegment = nil
        }

        // MARK: Audio track menu

        func configureAudioMenu(
            streams: [MediaStream],
            selectedIndex: Int?,
            isTranscoded: Bool,
            onAudioTrackSelected: @escaping (Int, TimeInterval) -> Void,
            controller: AVPlayerViewController
        ) {
            self.audioStreams = streams
            if currentAudioIndex == nil {
                currentAudioIndex = selectedIndex
            }
            self.isTranscoded = isTranscoded
            self.onAudioTrackSelected = onAudioTrackSelected
            self.controller = controller
            rebuildAudioMenu()
        }

        private func rebuildAudioMenu() {
            guard let controller, audioStreams.count > 1 else {
                controller?.transportBarCustomMenuItems = []
                return
            }

            let actions = audioStreams.map { stream in
                UIAction(
                    title: stream.displayTitle ?? stream.language ?? "Track \(stream.index ?? 0)",
                    state: stream.index == currentAudioIndex ? .on : .off
                ) { [weak self] _ in
                    self?.selectAudioTrack(stream)
                }
            }
            let menu = UIMenu(title: "Audio", image: UIImage(systemName: "music.note.list"), children: actions)
            controller.transportBarCustomMenuItems = [menu]
            print("Pelagica playback: set transportBarCustomMenuItems with \(actions.count) audio track(s)")
        }

        private func selectAudioTrack(_ stream: MediaStream) {
            print("""
            Pelagica playback: tapped audio track index \(stream.index.map(String.init) ?? "nil") \
            (\(stream.displayTitle ?? stream.language ?? "?")), current was \(currentAudioIndex.map(String.init) ?? "nil"), \
            isTranscoded: \(isTranscoded)
            """)
            guard let index = stream.index, index != currentAudioIndex else {
                print("Pelagica playback: selectAudioTrack bailed early (no index or already selected)")
                return
            }
            currentAudioIndex = index

            if isTranscoded {
                let seconds = controller?.player?.currentTime().seconds ?? 0
                onAudioTrackSelected?(index, seconds.isFinite ? seconds : 0)
            } else {
                selectDirectPlayAudioTrack(index: index)
            }
            rebuildAudioMenu()
        }

        private func selectDirectPlayAudioTrack(index: Int) {
            guard let asset = controller?.player?.currentItem?.asset else { return }
            let streams = audioStreams
            Task { [weak self] in
                guard let group = try? await asset.loadMediaSelectionGroup(for: .audible) else { return }

                let position = streams.firstIndex { $0.index == index } ?? 0
                guard position < group.options.count else { return }
                let option = group.options[position]

                await MainActor.run {
                    self?.controller?.player?.currentItem?.select(option, in: group)
                }
            }
        }
    }
}
