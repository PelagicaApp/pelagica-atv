//
//  ThemeSongPlayer.swift
//  Pelagica
//

import AVFoundation
import Get
import JellyfinAPI

@MainActor
final class ThemeSongPlayer {
    static let enabledDefaultsKey = "playThemeSongs"

    private static let volume: Float = 0.3
    private static let fadeInDuration: TimeInterval = 2
    private static let fadeOutDuration: TimeInterval = 1
    private static let fadeSteps = 20

    private var player: AVPlayer?
    private var fadeInTask: Task<Void, Never>?
    private var isStopped = false

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledDefaultsKey) as? Bool ?? true
    }

    func play(for item: BaseItemDto, appState: AppState) async {
        guard Self.isEnabled, player == nil,
              item.type == .movie || item.type == .series,
              let client = appState.client, let itemID = item.id else { return }
        isStopped = false

        let userID = appState.currentUser?.id
        let songs = try? await client.send(Paths.getThemeSongs(itemID: itemID, parameters: .init(
            userID: userID,
            isInheritFromParent: true
        ))).value.items
        guard let songID = songs?.first?.id, !Task.isCancelled, !isStopped, player == nil else { return }

        let request = Paths.getUniversalAudioStream(itemID: songID, parameters: .init(
            container: ["mp3", "aac", "m4a", "flac", "alac", "wav"],
            userID: userID,
            transcodingContainer: "mp3",
            transcodingProtocol: .http
        ))
        guard let url = client.url(with: request, queryAPIKey: true) else { return }

        let player = AVPlayer(url: url)
        player.volume = 0
        self.player = player
        player.play()
        fadeInTask = Task {
            await Self.fade(player, to: Self.volume, over: Self.fadeInDuration)
        }
    }

    /// Pass `fade: false` when other playback is about to start, so the two don't overlap
    func stop(fade: Bool = true) {
        isStopped = true
        guard let player else { return }
        self.player = nil
        fadeInTask?.cancel()
        guard fade else {
            player.pause()
            return
        }
        Task {
            await Self.fade(player, to: 0, over: Self.fadeOutDuration)
            player.pause()
        }
    }

    private static func fade(_ player: AVPlayer, to target: Float, over duration: TimeInterval) async {
        let start = player.volume
        for step in 1...fadeSteps {
            guard (try? await Task.sleep(for: .seconds(duration / Double(fadeSteps)))) != nil else { return }
            player.volume = start + (target - start) * Float(step) / Float(fadeSteps)
        }
    }
}
