//
//  NowPlayingPublisher.swift
//  Pelagica
//

import MediaPlayer
import UIKit

final class NowPlayingPublisher {
    struct Handlers {
        var play: () -> Void
        var pause: () -> Void
        var togglePlayPause: () -> Void
        var seek: (TimeInterval) -> Void
        var jump: (TimeInterval) -> Void
    }

    private var info: [String: Any] = [:]
    private var commandTargets: [(MPRemoteCommand, Any)] = []

    static let skipInterval: TimeInterval = 10

    func activate(handlers: Handlers) {
        guard commandTargets.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()

        func register(_ command: MPRemoteCommand, _ action: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
            command.isEnabled = true
            commandTargets.append((command, command.addTarget(handler: action)))
        }

        register(center.playCommand) { _ in handlers.play(); return .success }
        register(center.pauseCommand) { _ in handlers.pause(); return .success }
        register(center.togglePlayPauseCommand) { _ in handlers.togglePlayPause(); return .success }

        center.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        register(center.skipForwardCommand) { event in
            handlers.jump((event as? MPSkipIntervalCommandEvent)?.interval ?? Self.skipInterval)
            return .success
        }
        register(center.skipBackwardCommand) { event in
            handlers.jump(-((event as? MPSkipIntervalCommandEvent)?.interval ?? Self.skipInterval))
            return .success
        }
        register(center.changePlaybackPositionCommand) { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            handlers.seek(event.positionTime)
            return .success
        }
    }

    func deactivate() {
        for (command, target) in commandTargets {
            command.removeTarget(target)
            command.isEnabled = false
        }
        commandTargets = []
        info = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    func setMetadata(title: String, subtitle: String?, overview: String?) {
        info[MPMediaItemPropertyTitle] = subtitle ?? title
        info[MPMediaItemPropertyArtist] = subtitle == nil ? nil : title
        info[MPMediaItemPropertyComments] = overview
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
        publish()
    }

    func setArtwork(_ image: UIImage?) {
        info[MPMediaItemPropertyArtwork] = image.map { image in MPMediaItemArtwork(boundsSize: image.size) { _ in image } }
        publish()
    }

    func updateTimeline(elapsed: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : nil
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        publish()
    }

    private func publish() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
