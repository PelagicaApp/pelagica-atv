//
//  TrailerPreview.swift
//  Pelagica
//

import Combine
import Get
import JellyfinAPI
import SwiftUI
import TVVLCKit

struct TrailerPreview: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    let item: BaseItemDto
    let isActive: Bool

    private static let focusDelay: Double = 1.5

    @StateObject private var player = TrailerPreviewPlayer()

    private struct PlaybackKey: Equatable {
        let itemID: String?
        let isActive: Bool
    }

    private var shouldPlay: Bool {
        isActive && scenePhase == .active
    }

    var body: some View {
        TrailerPreviewSurface(view: player.videoView)
            .opacity(player.isRendering ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: player.isRendering)
            .allowsHitTesting(false)
            .task(id: PlaybackKey(itemID: item.id, isActive: shouldPlay)) {
                guard shouldPlay else {
                    player.stop()
                    return
                }
                try? await Task.sleep(for: .seconds(Self.focusDelay))
                guard !Task.isCancelled, let url = await trailerURL(), !Task.isCancelled else { return }
                player.play(url: url)
            }
            .onDisappear { player.stop() }
    }

    private func trailerURL() async -> URL? {
        guard let client = appState.client, let itemID = item.id, (item.localTrailerCount ?? 1) > 0 else { return nil }
        let trailers = try? await client.send(Paths.getLocalTrailers(itemID: itemID, userID: appState.currentUser?.id)).value
        guard let trailerID = trailers?.first?.id else { return nil }
        let request = Paths.getVideoStream(itemID: trailerID, parameters: .init(
            isStatic: true,
            mediaSourceID: trailerID
        ))
        return client.url(with: request, queryAPIKey: true)
    }
}

final class TrailerPreviewPlayer: NSObject, ObservableObject {
    @Published private(set) var isRendering = false

    let videoView = UIView()
    private var player: VLCMediaPlayer?

    override init() {
        super.init()
        videoView.backgroundColor = .clear
    }

    func play(url: URL) {
        stop()
        let media = VLCMedia(url: url)
        media.addOption(":no-audio")
        media.addOption(":input-repeat=65535")
        media.addOption(":network-caching=\(VLCPlayerController.networkCachingMilliseconds)")

        let player = VLCMediaPlayer()
        player.drawable = videoView
        player.delegate = self
        player.media = media
        self.player = player
        player.play()
    }

    func stop() {
        isRendering = false
        guard let player else { return }
        self.player = nil
        player.delegate = nil
        player.stop()
    }
}

extension TrailerPreviewPlayer: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        MainActor.assumeIsolated {
            guard let player = aNotification.object as? VLCMediaPlayer, player === self.player, !isRendering else { return }
            isRendering = true
        }
    }
}

private struct TrailerPreviewSurface: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
