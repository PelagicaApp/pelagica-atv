//
//  VLCPlayerController.swift
//  Pelagica
//

import AVFoundation
import Combine
import JellyfinAPI
import TVVLCKit
import UIKit

final class PlaybackClock: ObservableObject {
    @Published fileprivate(set) var currentSeconds: TimeInterval = 0
    @Published fileprivate(set) var durationSeconds: TimeInterval = 0
    /// Where the user is scrubbing to, before the seek is committed. `nil` when not scrubbing.
    @Published fileprivate(set) var scrubSeconds: TimeInterval?
}

final class VLCPlayerController: NSObject, ObservableObject {
    let clock = PlaybackClock()
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = true

    var onProgress: ((TimeInterval, Bool) -> Void)?
    var onPlaybackEnded: (() -> Void)?
    var onPlaybackFailed: (() -> Void)?

    let videoView = UIView()

    var currentSeconds: TimeInterval {
        get { clock.currentSeconds }
        set { if clock.currentSeconds != newValue { clock.currentSeconds = newValue } }
    }

    var durationSeconds: TimeInterval {
        get { clock.durationSeconds }
        set { if clock.durationSeconds != newValue { clock.durationSeconds = newValue } }
    }

    private let player = VLCMediaPlayer()
    private let nowPlaying = NowPlayingPublisher()
    private var embeddedAudioStreams: [MediaStream] = []
    private var embeddedSubtitleStreams: [MediaStream] = []
    private var pendingAudioStream: MediaStream?
    private var pendingSubtitle: SubtitleSelection = .unchanged
    private var didApplyInitialTracks = false
    private var didReachEnd = false
    private var lastProgressReport: TimeInterval = -.infinity
    /// VLC keeps reporting the pre-seek time for a moment after a seek. Those updates are ignored until it lands near the target (or the deadline passes) so the scrubber doesn't snap back
    private var pendingSeek: (target: TimeInterval, deadline: Date)?

    private static let seekSettleTolerance: TimeInterval = 1.5
    private static let seekSettleTimeout: TimeInterval = 3

    /// Jellyfin stream index -> VLC subtitle track ID for external subtitles loaded as playback slaves.
    private var externalSubtitleTrackIDs: [Int: Int32] = [:]
    /// An external subtitle that has been handed to VLC but whose track ID hasn't shown up yet.
    private var awaitingExternalSubtitle: (streamIndex: Int, knownTrackIDs: Set<Int32>)?

    enum SubtitleSelection {
        case unchanged
        case off
        case embedded(MediaStream)
        case external(MediaStream, URL)
    }

    override init() {
        super.init()
        videoView.backgroundColor = .black
        player.drawable = videoView
        player.delegate = self
    }

    // MARK: Loading

    func load(
        url: URL,
        startSeconds: TimeInterval,
        knownDurationSeconds: TimeInterval?,
        displayAspectRatio: String? = nil,
        mediaStreams: [MediaStream],
        audioStream: MediaStream?,
        subtitle: SubtitleSelection
    ) {
        Self.activateAudioSession()

        embeddedAudioStreams = mediaStreams.filter { $0.type == .audio && $0.isExternal != true }
        embeddedSubtitleStreams = mediaStreams.filter { $0.type == .subtitle && $0.isExternal != true }
        pendingAudioStream = audioStream
        pendingSubtitle = subtitle
        didApplyInitialTracks = false
        didReachEnd = false
        externalSubtitleTrackIDs = [:]
        awaitingExternalSubtitle = nil
        pendingSeek = nil
        clock.scrubSeconds = nil
        durationSeconds = knownDurationSeconds ?? 0
        currentSeconds = startSeconds
        setBuffering(true)

        let media = VLCMedia(url: url)
        media.addOption(":network-caching=1500")
        if startSeconds > 0 {
            media.addOption(":start-time=\(startSeconds)")
        }
        player.media = media
        setAspectRatioOverride(displayAspectRatio)
        player.play()
        UIApplication.shared.isIdleTimerDisabled = true
        activateNowPlaying()
        publishTimeline()
    }

    private func setAspectRatioOverride(_ ratio: String?) {
        guard let ratio, let cString = strdup(ratio) else {
            player.videoAspectRatio = nil
            return
        }
        print("Pelagica playback: forcing display aspect ratio \(ratio)")
        // libvlc copies the value
        player.videoAspectRatio = cString
        free(cString)
    }

    func stop() {
        player.stop()
        player.media = nil
        nowPlaying.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
        Self.deactivateAudioSession()
    }

    // MARK: Audio session

    private static let audioSessionQueue = DispatchQueue(label: "app.pelagica.audio-session", qos: .userInitiated)

    private static func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        audioSessionQueue.async {
            do {
                try session.setCategory(.playback, mode: .moviePlayback)
            } catch {
                print("Pelagica playback: failed to set audio session category: \(error)")
            }
            if #available(tvOS 27.0, *) {
                session.activate(options: []) { activated, error in
                    if !activated { print("Pelagica playback: failed to activate audio session: \(String(describing: error))") }
                }
            } else {
                do {
                    try session.setActive(true)
                } catch {
                    print("Pelagica playback: failed to activate audio session: \(error)")
                }
            }
        }
    }

    private static func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        audioSessionQueue.async {
            if #available(tvOS 27.0, *) {
                session.deactivate(options: .notifyOthersOnDeactivation) { _, _ in }
            } else {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    // MARK: Now Playing

    func setNowPlayingMetadata(title: String, subtitle: String?, overview: String?) {
        nowPlaying.setMetadata(title: title, subtitle: subtitle, overview: overview)
        publishTimeline()
    }

    func setNowPlayingArtwork(_ image: UIImage?) {
        nowPlaying.setArtwork(image)
    }

    private func activateNowPlaying() {
        nowPlaying.activate(handlers: .init(
            play: { [weak self] in self?.player.play() },
            pause: { [weak self] in self?.player.pause() },
            togglePlayPause: { [weak self] in self?.togglePlayPause() },
            seek: { [weak self] in self?.seek(to: $0) },
            jump: { [weak self] in self?.jump(by: $0) }
        ))
    }

    private func publishTimeline() {
        nowPlaying.updateTimeline(elapsed: currentSeconds, duration: durationSeconds, isPlaying: isPlaying)
    }

    // MARK: Transport

    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(0, durationSeconds > 0 ? min(seconds, durationSeconds - 1) : seconds)
        player.time = VLCTime(int: Int32(clamped * 1000))
        pendingSeek = (clamped, Date().addingTimeInterval(Self.seekSettleTimeout))
        currentSeconds = clamped
        publishTimeline()
    }

    func jump(by seconds: TimeInterval) {
        seek(to: currentSeconds + seconds)
    }

    // MARK: Scrubbing

    var isScrubbing: Bool { clock.scrubSeconds != nil }

    /// Moves the scrub position without touching playback; call `commitScrub()` to seek there
    func scrub(by seconds: TimeInterval) {
        let base = clock.scrubSeconds ?? currentSeconds
        let upperBound = durationSeconds > 0 ? durationSeconds - 1 : .greatestFiniteMagnitude
        clock.scrubSeconds = min(max(0, base + seconds), upperBound)
    }

    func commitScrub() {
        guard let target = clock.scrubSeconds else { return }
        clock.scrubSeconds = nil
        seek(to: target)
    }

    func cancelScrub() {
        clock.scrubSeconds = nil
    }

    // MARK: Tracks

    func selectAudio(_ stream: MediaStream) {
        guard didApplyInitialTracks else {
            pendingAudioStream = stream
            return
        }
        applyAudio(stream)
    }

    func selectSubtitle(_ selection: SubtitleSelection) {
        guard didApplyInitialTracks else {
            pendingSubtitle = selection
            return
        }
        applySubtitle(selection)
    }

    private func applyAudio(_ stream: MediaStream) {
        guard
            let position = embeddedAudioStreams.firstIndex(where: { $0.index == stream.index }),
            let trackID = trackIDs(player.audioTrackIndexes)[safe: position]
        else { return }
        player.currentAudioTrackIndex = trackID
    }

    private func applySubtitle(_ selection: SubtitleSelection) {
        switch selection {
        case .unchanged:
            return
        case .off:
            player.currentVideoSubTitleIndex = -1
        case let .embedded(stream):
            guard
                let position = embeddedSubtitleStreams.firstIndex(where: { $0.index == stream.index }),
                let trackID = trackIDs(player.videoSubTitlesIndexes)[safe: position]
            else {
                player.currentVideoSubTitleIndex = -1
                return
            }
            player.currentVideoSubTitleIndex = trackID
        case let .external(stream, url):
            guard let streamIndex = stream.index else { return }
            if let trackID = externalSubtitleTrackIDs[streamIndex] {
                player.currentVideoSubTitleIndex = trackID
                return
            }
            awaitingExternalSubtitle = (streamIndex, Set(trackIDs(player.videoSubTitlesIndexes)))
            player.addPlaybackSlave(url, type: .subtitle, enforce: true)
        }
    }

    /// VLC lists a "Disable" pseudo-track with ID -1 first. Strip it so positions line up with Jellyfin's streams.
    private func trackIDs(_ raw: [Any]?) -> [Int32] {
        (raw ?? []).compactMap { ($0 as? NSNumber)?.int32Value }.filter { $0 != -1 }
    }

    private func resolveAwaitingExternalSubtitle() {
        guard let awaiting = awaitingExternalSubtitle else { return }
        guard let newID = trackIDs(player.videoSubTitlesIndexes).first(where: { !awaiting.knownTrackIDs.contains($0) }) else { return }
        externalSubtitleTrackIDs[awaiting.streamIndex] = newID
        awaitingExternalSubtitle = nil
        player.currentVideoSubTitleIndex = newID
    }

    // MARK: State updates

    private func setPlaying(_ value: Bool) {
        guard isPlaying != value else { return }
        isPlaying = value
        publishTimeline()
    }

    private func setBuffering(_ value: Bool) {
        if isBuffering != value { isBuffering = value }
    }

    private func handleStateChange() {
        switch player.state {
        case .opening, .buffering:
            setBuffering(!player.isPlaying)
        case .playing:
            setBuffering(false)
            setPlaying(true)
            if !didApplyInitialTracks {
                didApplyInitialTracks = true
                if let pendingAudioStream { applyAudio(pendingAudioStream) }
                applySubtitle(pendingSubtitle)
                pendingAudioStream = nil
                pendingSubtitle = .unchanged
            }
        case .paused:
            setBuffering(false)
            setPlaying(false)
            onProgress?(currentSeconds, true)
        case .ended:
            setPlaying(false)
            finish()
        case .stopped:
            setPlaying(false)
            // VLC reports `stopped` rather than `ended` for some network streams that run out
            if durationSeconds > 0, currentSeconds >= durationSeconds - 2 {
                finish()
            }
        case .esAdded:
            resolveAwaitingExternalSubtitle()
        case .error:
            setPlaying(false)
            print("Pelagica playback: VLC reported an error for \(player.media?.url?.absoluteString ?? "nil")")
            onPlaybackFailed?()
        default:
            break
        }
    }

    private func handleTimeChange() {
        setBuffering(false)
        let seconds = Double(player.time.intValue) / 1000
        if let pendingSeek {
            if abs(seconds - pendingSeek.target) <= Self.seekSettleTolerance || Date() >= pendingSeek.deadline {
                self.pendingSeek = nil
            } else {
                return
            }
        }
        if seconds.isFinite { currentSeconds = seconds }
        if let length = player.media?.length.intValue, length > 0, Double(length) / 1000 != durationSeconds {
            durationSeconds = Double(length) / 1000
            publishTimeline()
        }
        resolveAwaitingExternalSubtitle()

        if abs(currentSeconds - lastProgressReport) >= 10 {
            lastProgressReport = currentSeconds
            onProgress?(currentSeconds, !player.isPlaying)
            publishTimeline()
        }
    }

    private func finish() {
        guard !didReachEnd else { return }
        didReachEnd = true
        UIApplication.shared.isIdleTimerDisabled = false
        onPlaybackEnded?()
    }
}

extension VLCPlayerController: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        MainActor.assumeIsolated { handleStateChange() }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        MainActor.assumeIsolated { handleTimeChange() }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
