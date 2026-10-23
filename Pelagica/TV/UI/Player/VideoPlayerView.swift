//
//  VideoPlayerView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct VideoPlayerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var session: PlaybackSession

    init(item: BaseItemDto, startTicks: Int = 0) {
        _session = StateObject(wrappedValue: PlaybackSession(item: item, startTicks: startTicks))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCVideoSurface(view: session.controller.videoView)
                .ignoresSafeArea()

            if session.didFailToResolve {
                VStack(spacing: 24) {
                    Text(i18n.t("player:playbackDecodeErrorFailed"))
                        .font(.title2)
                        .foregroundStyle(.white)
                    Button(i18n.t("close")) { dismiss() }
                }
            } else if session.isLoaded {
                PlayerControlsOverlay(
                    controller: session.controller,
                    title: session.title,
                    subtitle: session.subtitle,
                    overview: session.currentItem.overview,
                    audioStreams: session.audioStreams,
                    selectedAudioIndex: session.selectedAudioStreamIndex,
                    subtitleStreams: session.subtitleStreams,
                    selectedSubtitleIndex: session.selectedSubtitleStreamIndex,
                    introRange: session.introRange,
                    outroRange: session.outroRange,
                    trickplay: session.trickplay,
                    playbackInfo: session.playbackInfo,
                    onSelectAudio: session.selectAudioTrack,
                    onSelectSubtitle: session.selectSubtitleTrack,
                    onClose: { dismiss() }
                )
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear { session.bind(appState: appState) }
        .onDisappear { session.end() }
        .onChange(of: session.isFinished) { _, isFinished in
            if isFinished { dismiss() }
        }
        .task(id: session.currentItem.id) {
            session.bind(appState: appState)
            await session.loadCurrentItem()
        }
        .task(id: session.currentMediaSourceID) {
            await session.loadTrickplay()
        }
    }
}
