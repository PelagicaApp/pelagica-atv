//
//  VideoPlayerView.swift
//  Pelagica
//

import AVKit
import CoreMedia
import Get
import JellyfinAPI
import SwiftUI

struct VideoPlayerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let item: BaseItemDto
    var startTicks: Int = 0

    @State private var streamURL: URL?
    @State private var startTimeSeconds: Double = 0
    @State private var didFailToResolve = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let streamURL {
                AVPlayerControllerView(
                    url: streamURL,
                    startTimeSeconds: startTimeSeconds,
                    title: playerTitle,
                    subtitle: playerSubtitle,
                    overview: item.overview
                )
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
            await resolvePlayback()
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

    private func resolvePlayback() async {
        guard let client = appState.client, let itemID = item.id else {
            didFailToResolve = true
            return
        }

        do {
            let info = try await client.send(Paths.getPostedPlaybackInfo(
                itemID: itemID,
                parameters: .init(userID: appState.currentUser?.id, startTimeTicks: startTicks),
                PlaybackInfoDto(deviceProfile: Self.deviceProfile, startTimeTicks: startTicks, userID: appState.currentUser?.id)
            )).value
            guard let mediaSource = info.mediaSources?.first, let mediaSourceID = mediaSource.id else {
                print("Pelagica playback: no media source in PlaybackInfo response for item \(itemID)")
                didFailToResolve = true
                return
            }

            let url: URL?
            if mediaSource.isSupportsDirectPlay == true {
                let request = Paths.getVideoStream(itemID: itemID, parameters: .init(
                    container: mediaSource.container,
                    isStatic: true,
                    playSessionID: info.playSessionID,
                    mediaSourceID: mediaSourceID
                ))
                url = client.url(with: request, queryAPIKey: true)
                startTimeSeconds = Double(startTicks) / 10_000_000
            } else if let transcodingPath = mediaSource.transcodingURL {
                url = resolvedTranscodingURL(path: transcodingPath, client: client)
                // The transcode already starts at startTicks server-side.
                startTimeSeconds = 0
            } else {
                url = nil
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
            streamURL = url
        } catch {
            print("Pelagica playback: PlaybackInfo request failed for item \(itemID): \(error)")
            didFailToResolve = true
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
}

private struct AVPlayerControllerView: UIViewControllerRepresentable {
    let url: URL
    let startTimeSeconds: Double
    let title: String
    var subtitle: String?
    var overview: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        item.externalMetadata = metadataItems()
        context.coordinator.observe(item)

        let player = AVPlayer(playerItem: item)
        if startTimeSeconds > 0 {
            player.seek(to: CMTime(seconds: startTimeSeconds, preferredTimescale: 1))
        }

        let controller = AVPlayerViewController()
        controller.player = player
        player.play()
        return controller
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

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }

    final class Coordinator: NSObject {
        private var statusObservation: NSKeyValueObservation?
        private var errorLogObserver: NSObjectProtocol?

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
    }
}
