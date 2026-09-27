//
//  PlayerControlsOverlay.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

enum SkipSegmentKind {
    case intro
    case outro

    var title: String {
        switch self {
        case .intro: return i18n.t("player:skipIntro")
        case .outro: return i18n.t("player:skipOutro")
        }
    }
}

struct PlayerControlsOverlay: View {
    @ObservedObject var controller: VLCPlayerController

    let title: String
    let subtitle: String?
    let overview: String?
    let audioStreams: [MediaStream]
    let selectedAudioIndex: Int?
    let subtitleStreams: [MediaStream]
    let selectedSubtitleIndex: Int?
    let introRange: ClosedRange<TimeInterval>?
    let outroRange: ClosedRange<TimeInterval>?
    let trickplay: TrickplayProvider?
    let onSelectAudio: (MediaStream) -> Void
    let onSelectSubtitle: (MediaStream?) -> Void
    let onClose: () -> Void

    private enum Field: Hashable {
        case scrubber
        case audio
        case subtitles
        case skip
        /// A row in the open track panel, keyed by stream index (`nil` for "Off").
        case trackOption(Int?)
    }

    private enum TrackPanel {
        case audio
        case subtitles
    }

    private struct TrackOption: Identifiable {
        let streamIndex: Int?
        let title: String
        var id: Int { streamIndex ?? -1 }
    }

    @FocusState private var focusedField: Field?
    @State private var controlsVisible = true
    @State private var hideGeneration = 0
    @State private var activeSkipSegment: ActiveSkipSegment?
    @State private var openPanel: TrackPanel?
    @State private var scrubGeneration = 0

    private static let jumpSeconds: TimeInterval = 10
    private static let autoHideDelay: Duration = .seconds(5)
    /// How long the scrub position rests before it's committed
    private static let scrubCommitDelay: Duration = .seconds(0.8)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.75), .clear, .clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(controlsVisible ? 1 : 0)

            if controller.isBuffering {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            }
            
            if !controller.isBuffering && !controller.isPlaying {
                Image(systemName: "pause.fill")
                    .foregroundColor(.white)
                    .padding(16)
                    .background(.black.opacity(0.6), in: Circle())
                    .scaleEffect(2)
            }

            VStack(alignment: .leading, spacing: 0) {
                header
                    .opacity(controlsVisible ? 1 : 0)
                Spacer()
                HStack(alignment: .bottom) {
                    if let openPanel, controlsVisible {
                        trackPanel(openPanel)
                            .padding(.bottom, 32)
                            .transition(.opacity)
                    }
                    Spacer()
                    if let activeSkipSegment {
                        Button {
                            controller.seek(to: activeSkipSegment.endSeconds)
                        } label: {
                            Label(activeSkipSegment.kind.title, systemImage: "forward.fill")
                        }
                        .focused($focusedField, equals: .skip)
                        .padding(.bottom, 32)
                    }
                }
                transportBar
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 60)
        }
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
        .animation(.easeInOut(duration: 0.2), value: openPanel)
        .onPlayPauseCommand {
            controller.commitScrub()
            controller.togglePlayPause()
            showControls()
        }
        .onExitCommand {
            if controller.isScrubbing {
                controller.cancelScrub()
                showControls()
            } else if let openPanel {
                closePanel(openPanel)
            } else if controlsVisible {
                hideControls()
            } else {
                onClose()
            }
        }
        .onAppear {
            focusedField = .scrubber
            scheduleAutoHide()
        }
        .onChange(of: activeSkipSegment?.kind) { _, kind in
            if kind != nil {
                focusedField = .skip
            } else if focusedField == .skip || focusedField == nil {
                focusedField = .scrubber
            }
        }
        .onReceive(controller.clock.$currentSeconds) { updateSkipSegment(at: $0) }
        .onChange(of: focusedField) { _, field in
            scheduleAutoHide()
            if field == nil {
                Task { @MainActor in
                    if focusedField == nil { focusedField = .scrubber }
                }
            }
        }
        .onChange(of: controller.isPlaying) { _, _ in scheduleAutoHide() }
        .task(id: hideGeneration) {
            try? await Task.sleep(for: Self.autoHideDelay)
            guard !Task.isCancelled, controller.isPlaying, focusedField == .scrubber, !controller.isScrubbing else { return }
            controlsVisible = false
        }
        .task(id: scrubGeneration) {
            guard controller.isScrubbing else { return }
            try? await Task.sleep(for: Self.scrubCommitDelay)
            guard !Task.isCancelled else { return }
            controller.commitScrub()
        }
    }

    private struct ActiveSkipSegment: Equatable {
        let kind: SkipSegmentKind
        let endSeconds: TimeInterval
    }

    /// Driven from the clock without observing it, so this view only re-renders when a segment starts or ends rather than on every position update.
    private func updateSkipSegment(at now: TimeInterval) {
        let segment: ActiveSkipSegment?
        if let introRange, introRange.contains(now) {
            segment = ActiveSkipSegment(kind: .intro, endSeconds: introRange.upperBound)
        } else if let outroRange, outroRange.contains(now) {
            segment = ActiveSkipSegment(kind: .outro, endSeconds: outroRange.upperBound)
        } else {
            segment = nil
        }
        if segment != activeSkipSegment {
            activeSkipSegment = segment
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let subtitle {
                Text(title)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(subtitle)
                    .font(.system(size: 40, weight: .bold))
            } else {
                Text(title)
                    .font(.system(size: 40, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .lineLimit(1)
    }

    // MARK: Transport bar

    private var transportBar: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button {
                if controller.isScrubbing {
                    controller.commitScrub()
                } else if controlsVisible {
                    controller.togglePlayPause()
                }
                showControls()
            } label: {
                ScrubberBar(clock: controller.clock, trickplay: trickplay)
                    .opacity(controlsVisible ? 1 : 0)
            }
            .buttonStyle(ScrubberButtonStyle())
            .focused($focusedField, equals: .scrubber)
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    controller.scrub(by: -Self.jumpSeconds)
                    scrubGeneration += 1
                case .right:
                    controller.scrub(by: Self.jumpSeconds)
                    scrubGeneration += 1
                default: break
                }
                showControls()
            }

            if controlsVisible {
                trackMenus
                    .transition(.opacity)
            }
        }
    }

    private var trackMenus: some View {
        HStack(spacing: 24) {
            if audioStreams.count > 1 {
                Button {
                    togglePanel(.audio)
                } label: {
                    Label(i18n.t("player:audioTracks"), systemImage: "waveform")
                }
                .focused($focusedField, equals: .audio)
            }

            if !subtitleStreams.isEmpty {
                Button {
                    togglePanel(.subtitles)
                } label: {
                    Label(i18n.t("subtitles"), systemImage: "captions.bubble")
                }
                .focused($focusedField, equals: .subtitles)
            }
        }
        .font(.system(size: 24, weight: .semibold))
        .focusSection()
    }

    // MARK: Track panel

    /// An in-overlay replacement for `Menu`: a system menu takes focus out of this view tree and
    /// doesn't reliably hand it back, which leaves the remote's commands with nowhere to go.
    private func trackPanel(_ panel: TrackPanel) -> some View {
        let options = trackOptions(for: panel)
        let selected = selectedIndex(for: panel)
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(options) { option in
                    Button {
                        select(option, in: panel)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "checkmark")
                                .opacity(option.streamIndex == selected ? 1 : 0)
                            Text(option.title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(TrackOptionButtonStyle())
                    .focused($focusedField, equals: .trackOption(option.streamIndex))
                }
            }
            .padding(16)
        }
        .scrollClipDisabled()
        .frame(width: 640)
        .frame(maxHeight: 560)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .focusSection()
    }

    private func trackOptions(for panel: TrackPanel) -> [TrackOption] {
        switch panel {
        case .audio:
            return audioStreams.map { TrackOption(streamIndex: $0.index, title: audioTitle(for: $0)) }
        case .subtitles:
            return [TrackOption(streamIndex: nil, title: i18n.t("player:off"))]
                + subtitleStreams.map { TrackOption(streamIndex: $0.index, title: subtitleTitle(for: $0)) }
        }
    }

    private func selectedIndex(for panel: TrackPanel) -> Int? {
        switch panel {
        case .audio: return selectedAudioIndex
        case .subtitles: return selectedSubtitleIndex
        }
    }

    private func togglePanel(_ panel: TrackPanel) {
        if openPanel == panel {
            closePanel(panel)
            return
        }
        openPanel = panel
        let selected = selectedIndex(for: panel)
        let hasSelectedRow = trackOptions(for: panel).contains { $0.streamIndex == selected }
        let firstRow = trackOptions(for: panel).first?.streamIndex
        // Defer until the panel's rows exist, otherwise the focus request is dropped.
        Task { @MainActor in
            focusedField = .trackOption(hasSelectedRow ? selected : firstRow)
        }
    }

    private func closePanel(_ panel: TrackPanel) {
        openPanel = nil
        focusedField = panel == .audio ? .audio : .subtitles
    }

    private func select(_ option: TrackOption, in panel: TrackPanel) {
        switch panel {
        case .audio:
            if let stream = audioStreams.first(where: { $0.index == option.streamIndex }) {
                onSelectAudio(stream)
            }
        case .subtitles:
            onSelectSubtitle(subtitleStreams.first { $0.index == option.streamIndex })
        }
        closePanel(panel)
    }

    private func audioTitle(for stream: MediaStream) -> String {
        stream.displayTitle ?? stream.language ?? "\(i18n.t("item:audio")) \(stream.index ?? 0)"
    }

    private func subtitleTitle(for stream: MediaStream) -> String {
        stream.displayTitle ?? stream.language ?? "\(i18n.t("item:subtitle")) \(stream.index ?? 0)"
    }

    // MARK: Visibility

    private func showControls() {
        controlsVisible = true
        scheduleAutoHide()
    }

    private func hideControls() {
        controlsVisible = false
        openPanel = nil
        if focusedField != .skip {
            focusedField = .scrubber
        }
    }

    private func scheduleAutoHide() {
        hideGeneration += 1
    }
}

// MARK: - Scrubber

private struct ScrubberBar: View {
    @ObservedObject var clock: PlaybackClock
    let trickplay: TrickplayProvider?

    @State private var previewWidth: CGFloat = 0

    private static let trackHeight: CGFloat = 10
    private static let headWidth: CGFloat = 6
    private static let headHeight: CGFloat = 30
    private static let previewGap: CGFloat = 28

    /// The scrub target while scrubbing, otherwise the playback position
    private var displayedSeconds: TimeInterval { clock.scrubSeconds ?? clock.currentSeconds }
    private var durationSeconds: TimeInterval { clock.durationSeconds }

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white.opacity(clock.scrubSeconds == nil ? 1 : 0.5))
                        .frame(width: width * fraction(of: clock.currentSeconds))
                }
                .frame(height: Self.trackHeight)
                .overlay(alignment: .leading) {
                    if let scrubSeconds = clock.scrubSeconds {
                        Capsule().fill(.white)
                            .frame(width: Self.headWidth, height: Self.headHeight)
                            .offset(x: width * fraction(of: scrubSeconds) - Self.headWidth / 2)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let scrubSeconds = clock.scrubSeconds {
                        let center = width * fraction(of: scrubSeconds)
                        let leading = min(max(0, center - previewWidth / 2), max(0, width - previewWidth))
                        ScrubPreview(seconds: scrubSeconds, trickplay: trickplay)
                            .fixedSize()
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { previewWidth = $0 }
                            .offset(x: leading, y: -(Self.trackHeight + Self.previewGap))
                    }
                }
            }
            .frame(height: Self.trackHeight)

            HStack {
                Text(Self.format(displayedSeconds))
                Spacer()
                Text("-" + Self.format(max(0, durationSeconds - displayedSeconds)))
            }
            .font(.system(size: 22, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func fraction(of seconds: TimeInterval) -> CGFloat {
        guard durationSeconds > 0 else { return 0 }
        return CGFloat(min(max(seconds / durationSeconds, 0), 1))
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.isFinite ? seconds : 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

private struct ScrubPreview: View {
    let seconds: TimeInterval
    let trickplay: TrickplayProvider?

    @State private var image: CGImage?

    private static let thumbnailWidth: CGFloat = 400

    var body: some View {
        VStack(spacing: 12) {
            if let trickplay {
                ZStack {
                    Color.black
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(
                    width: Self.thumbnailWidth,
                    height: Self.thumbnailWidth * CGFloat(trickplay.thumbnailHeight) / CGFloat(trickplay.thumbnailWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.7), lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 16)
            }

            Text(ScrubberBar.format(seconds))
                .font(.system(size: 26, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6), in: Capsule())
        }
        .task(id: trickplay?.thumbnailIndex(at: seconds)) {
            guard let trickplay else { return }
            let loaded = await trickplay.thumbnail(at: trickplay.thumbnailIndex(at: seconds))
            if !Task.isCancelled, let loaded { image = loaded }
        }
    }
}

private struct TrackOptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TrackOptionBody(configuration: configuration)
    }

    private struct TrackOptionBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(isFocused ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(isFocused ? 1 : 0))
                )
                .scaleEffect(isFocused ? 1.02 : 1)
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }
}

private struct ScrubberButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}
