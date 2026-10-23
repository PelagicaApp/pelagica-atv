//
//  PlayerView.swift
//  Pelagica
//

import Combine
import JellyfinAPI
import SwiftUI

struct PlayerView: View {
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
                VStack(spacing: 20) {
                    Text(i18n.t("player:playbackDecodeErrorFailed"))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button(i18n.t("close")) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .foregroundStyle(.white)
                .padding()
            } else if session.isLoaded {
                PlayerControls(session: session, controller: session.controller, onClose: { dismiss() })
            } else {
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
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

extension View {
    func playerCover(_ target: Binding<PlaybackTarget?>) -> some View {
        fullScreenCover(item: target) { target in
            PlayerView(item: target.item, startTicks: target.startTicks)
        }
        .onChange(of: target.wrappedValue == nil) { _, isNil in
            OrientationLock.set(isNil ? .portrait : .landscape)
        }
    }
}

@MainActor
final class PlayerPresenter: ObservableObject {
    @Published var target: PlaybackTarget?

    func play(_ item: BaseItemDto) {
        guard item.id != nil else { return }
        target = PlaybackTarget(item: item, startTicks: item.userData?.playbackPositionTicks ?? 0)
    }
}
