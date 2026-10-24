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
    @AppStorage("playerDisplayMode") private var displayMode: PlayerDisplayMode = .fit
    @State private var surfaceSize: CGSize = .zero

    init(item: BaseItemDto, startTicks: Int = 0) {
        _session = StateObject(wrappedValue: PlaybackSession(item: item, startTicks: startTicks))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCVideoSurface(view: session.controller.videoView)
                .onGeometryChange(for: CGSize.self, of: \.size) { surfaceSize = $0 }
                .ignoresSafeArea(edges: displayMode == .safeArea ? .vertical : .all)

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
        .simultaneousGesture(displayModeGesture)
        .sensoryFeedback(.selection, trigger: displayMode)
        .onChange(of: displayMode, initial: true) { applyCrop() }
        .onChange(of: surfaceSize) { applyCrop() }
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

    // MARK: Display mode

    private var displayModeGesture: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                let step = value.magnification > 1.15 ? 1 : value.magnification < 0.87 ? -1 : 0
                let modes = PlayerDisplayMode.allCases
                guard step != 0, let index = modes.firstIndex(of: displayMode), modes.indices.contains(index + step) else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    displayMode = modes[index + step]
                }
            }
    }

    private func applyCrop() {
        session.controller.setCropToFill(displayMode == .fill ? surfaceSize : nil)
    }
}

enum PlayerDisplayMode: String, CaseIterable {
    case safeArea
    case fit
    case fill
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
