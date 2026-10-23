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
    @State private var isShowingTracks = false

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
                    PlayerTimeline(clock: controller.clock, controller: controller, onInteraction: scheduleHide)
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
    }

    private func jumpZone(by seconds: TimeInterval) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                controller.jump(by: seconds)
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

            if session.audioStreams.count > 1 || !session.subtitleStreams.isEmpty {
                tracksMenu
            }
        }
    }

    private var tracksMenu: some View {
        Button {
            isShowingTracks = true
        } label: {
            Image(systemName: "captions.bubble")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .popover(isPresented: $isShowingTracks) {
            tracksList
                .frame(minWidth: 280, idealHeight: 360)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var tracksList: some View {
        List {
            if session.audioStreams.count > 1 {
                Section(i18n.t("player:audioTracks")) {
                    ForEach(session.audioStreams, id: \.index) { stream in
                        trackRow(audioTitle(for: stream), isSelected: stream.index == session.selectedAudioStreamIndex) {
                            session.selectAudioTrack(stream)
                        }
                    }
                }
            }

            if !session.subtitleStreams.isEmpty {
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
            isShowingTracks = false
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
    let onInteraction: () -> Void

    @State private var dragSeconds: TimeInterval?

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { dragSeconds ?? clock.currentSeconds },
                    set: { dragSeconds = $0 }
                ),
                in: 0...max(clock.durationSeconds, 1),
                onEditingChanged: { isEditing in
                    if !isEditing, let dragSeconds {
                        controller.seek(to: dragSeconds)
                        self.dragSeconds = nil
                    }
                    onInteraction()
                }
            )
            .tint(.white)

            HStack {
                Text(Self.format(dragSeconds ?? clock.currentSeconds))
                Spacer()
                Text("-" + Self.format(max(clock.durationSeconds - (dragSeconds ?? clock.currentSeconds), 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.8))
        }
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
