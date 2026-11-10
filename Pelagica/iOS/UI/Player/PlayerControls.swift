//
//  PlayerControls.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct PlayerControls: View {
    @ObservedObject var session: PlaybackSession
    @ObservedObject var controller: VLCPlayerController
    let onClose: () -> Void

    @State private var isVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var presentedTrackMenu: TrackMenu?
    @State private var doubleTapJumps = 0

    private enum TrackMenu {
        case audio, subtitles
    }

    private var isShowingTracks: Bool { presentedTrackMenu != nil }

    private static let jumpInterval: TimeInterval = 10
    private static let autoHideDelay: Duration = .seconds(4)

    var body: some View {
        ZStack {
            tapSurface

            if isVisible {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    transportButtons
                    Spacer()
                    PlayerTimeline(
                        clock: controller.clock,
                        controller: controller,
                        trickplay: session.trickplay,
                        onEditingChanged: { isEditing in
                            if isEditing { show(autoHide: false) } else { scheduleHide() }
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .transition(.opacity)
            }

            SkipSegmentButton(clock: controller.clock, session: session)
                .padding(.trailing, 24)
                .padding(.bottom, isVisible ? 96 : 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            if controller.isBuffering {
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .onAppear(perform: scheduleHide)
        .onChange(of: controller.isPlaying) { _, isPlaying in
            if isPlaying { scheduleHide() } else { show(autoHide: false) }
        }
        .onChange(of: isShowingTracks) { _, isShowing in
            if isShowing { show(autoHide: false) } else { scheduleHide() }
        }
    }

    // MARK: Gestures

    private var tapSurface: some View {
        HStack(spacing: 0) {
            jumpZone(by: -Self.jumpInterval)
            jumpZone(by: Self.jumpInterval)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .light), trigger: doubleTapJumps)
    }

    private func jumpZone(by seconds: TimeInterval) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                controller.jump(by: seconds)
                doubleTapJumps += 1
                show()
            }
            .onTapGesture {
                if isVisible { hide() } else { show() }
            }
    }

    // MARK: Bars

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle = session.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            if session.audioStreams.count > 1 {
                trackMenuButton(.audio, systemImage: "waveform")
            }

            if !session.subtitleStreams.isEmpty {
                trackMenuButton(.subtitles, systemImage: "captions.bubble")
            }
        }
    }

    private func trackMenuButton(_ menu: TrackMenu, systemImage: String) -> some View {
        Button {
            presentedTrackMenu = menu
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .popover(isPresented: Binding(
            get: { presentedTrackMenu == menu },
            set: { if !$0, presentedTrackMenu == menu { presentedTrackMenu = nil } }
        )) {
            trackList(for: menu)
                .frame(minWidth: 280, idealHeight: 360)
                .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder
    private func trackList(for menu: TrackMenu) -> some View {
        switch menu {
        case .audio:
            List {
                Section(i18n.t("player:audioTracks")) {
                    ForEach(session.audioStreams, id: \.index) { stream in
                        trackRow(audioTitle(for: stream), isSelected: stream.index == session.selectedAudioStreamIndex) {
                            session.selectAudioTrack(stream)
                        }
                    }
                }
            }
        case .subtitles:
            List {
                Section(i18n.t("subtitles")) {
                    trackRow(i18n.t("player:off"), isSelected: session.selectedSubtitleStreamIndex == nil) {
                        session.selectSubtitleTrack(nil)
                    }
                    ForEach(session.subtitleStreams, id: \.index) { stream in
                        trackRow(subtitleTitle(for: stream), isSelected: stream.index == session.selectedSubtitleStreamIndex) {
                            session.selectSubtitleTrack(stream)
                        }
                    }
                }
            }
        }
    }

    private func trackRow(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            presentedTrackMenu = nil
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func audioTitle(for stream: MediaStream) -> String {
        stream.displayTitle ?? stream.language ?? "\(i18n.t("item:audio")) \(stream.index ?? 0)"
    }

    private func subtitleTitle(for stream: MediaStream) -> String {
        stream.displayTitle ?? stream.language ?? "\(i18n.t("item:subtitle")) \(stream.index ?? 0)"
    }

    private var transportButtons: some View {
        HStack(spacing: 56) {
            Button {
                controller.jump(by: -Self.jumpInterval)
                scheduleHide()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 30, weight: .semibold))
            }

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .frame(width: 64, height: 64)
                    .contentTransition(.symbolEffect(.replace))
            }

            Button {
                controller.jump(by: Self.jumpInterval)
                scheduleHide()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 30, weight: .semibold))
            }
        }
        .opacity(controller.isBuffering ? 0 : 1)
    }

    // MARK: Visibility

    private func show(autoHide: Bool = true) {
        isVisible = true
        if autoHide { scheduleHide() } else { hideTask?.cancel() }
    }

    private func hide() {
        hideTask?.cancel()
        isVisible = false
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: Self.autoHideDelay)
            guard !Task.isCancelled, controller.isPlaying, !controller.isScrubbing, !isShowingTracks else { return }
            isVisible = false
        }
    }
}

private struct PlayerTimeline: View {
    @ObservedObject var clock: PlaybackClock
    let controller: VLCPlayerController
    let trickplay: TrickplayProvider?
    let onEditingChanged: (Bool) -> Void

    @State private var dragStartSeconds: TimeInterval?
    @GestureState private var isDragging = false
    @State private var trackWidth: CGFloat = 0
    @State private var previewWidth: CGFloat = 0

    private static let touchHeight: CGFloat = 32
    private static let previewGap: CGFloat = 8
    private static let tapTolerance: CGFloat = 4
    private static let accessibilityStep: TimeInterval = 10

    private var displayedSeconds: TimeInterval { clock.scrubSeconds ?? clock.currentSeconds }

    var body: some View {
        VStack(spacing: 6) {
            track

            HStack {
                Text(Self.format(displayedSeconds))
                Spacer()
                Text("-" + Self.format(max(clock.durationSeconds - displayedSeconds, 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.8))
        }
        .task(id: trickplay.map(ObjectIdentifier.init)) {
            guard let trickplay else { return }
            _ = await trickplay.thumbnail(at: trickplay.thumbnailIndex(at: clock.currentSeconds))
        }
        .onChange(of: isDragging) { _, isDragging in
            guard !isDragging, dragStartSeconds != nil else { return }
            dragStartSeconds = nil
            controller.cancelScrub()
            onEditingChanged(false)
        }
    }

    private var track: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.3))
            Capsule().fill(.white)
                .frame(width: trackWidth * fraction(of: displayedSeconds))
        }
        .frame(height: controller.isScrubbing ? 8 : 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
        .frame(maxWidth: .infinity, minHeight: Self.touchHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .bottomLeading) {
            if let scrubSeconds = clock.scrubSeconds {
                ScrubPreview(seconds: scrubSeconds, trickplay: trickplay)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { previewWidth = $0 }
                    .offset(x: previewLeading(for: scrubSeconds), y: -(Self.touchHeight + Self.previewGap))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.15), value: controller.isScrubbing)
        .gesture(scrubGesture)
        .accessibilityElement()
        .accessibilityValue(Self.format(displayedSeconds))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: controller.jump(by: Self.accessibilityStep)
            case .decrement: controller.jump(by: -Self.accessibilityStep)
            @unknown default: break
            }
        }
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let start: TimeInterval
                if let dragStartSeconds {
                    start = dragStartSeconds
                } else {
                    start = clock.currentSeconds
                    dragStartSeconds = start
                    onEditingChanged(true)
                }
                guard trackWidth > 0 else { return }
                controller.scrub(to: start + value.translation.width / trackWidth * clock.durationSeconds)
            }
            .onEnded { value in
                dragStartSeconds = nil
                if abs(value.translation.width) < Self.tapTolerance {
                    controller.cancelScrub()
                } else {
                    controller.commitScrub()
                }
                onEditingChanged(false)
            }
    }

    private func fraction(of seconds: TimeInterval) -> CGFloat {
        guard clock.durationSeconds > 0 else { return 0 }
        return CGFloat(min(max(seconds / clock.durationSeconds, 0), 1))
    }

    private func previewLeading(for seconds: TimeInterval) -> CGFloat {
        let center = trackWidth * fraction(of: seconds)
        return min(max(0, center - previewWidth / 2), max(0, trackWidth - previewWidth))
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

    private static let thumbnailWidth: CGFloat = 180

    var body: some View {
        VStack(spacing: 6) {
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.7), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 8)
            }

            Text(PlayerTimeline.format(seconds))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
        }
        .task(id: trickplay?.thumbnailIndex(at: seconds)) {
            guard let trickplay else { return }
            let loaded = await trickplay.thumbnail(at: trickplay.thumbnailIndex(at: seconds))
            if !Task.isCancelled, let loaded { image = loaded }
        }
    }
}

private struct SkipSegmentButton: View {
    @ObservedObject var clock: PlaybackClock
    @ObservedObject var session: PlaybackSession

    var body: some View {
        if let segment = activeSegment {
            Button {
                session.controller.seek(to: segment.end)
            } label: {
                Label(segment.title, systemImage: "forward.end.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
            }
            .transition(.opacity)
        }
    }

    private var activeSegment: (title: String, end: TimeInterval)? {
        let now = clock.currentSeconds
        if let intro = session.introRange, intro.contains(now) {
            return (i18n.t("player:skipIntro"), intro.upperBound)
        }
        if let outro = session.outroRange, outro.contains(now) {
            return (i18n.t("player:skipOutro"), outro.upperBound)
        }
        return nil
    }
}
