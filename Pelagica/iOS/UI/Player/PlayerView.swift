//
//  PlayerView.swift
//  Pelagica
//

import Combine
import JellyfinAPI
import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subtitleStyleStore: SubtitleStyleStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var session: PlaybackSession
    @AppStorage("playerDisplayMode") private var displayMode: PlayerDisplayMode = .fit
    @State private var surfaceSize: CGSize = .zero
    @State private var isRotating = false
    @State private var dismissDragOffset: CGFloat = 0
    @State private var isDismissDragging = false

    private static let dismissDistance: CGFloat = 120
    private static let dismissPredictedDistance: CGFloat = 320

    init(item: BaseItemDto, startTicks: Int = 0) {
        _session = StateObject(wrappedValue: PlaybackSession(item: item, startTicks: startTicks))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                VLCVideoSurface(view: session.controller.videoView)
                    .onGeometryChange(for: CGSize.self, of: \.size) { surfaceSize = $0 }
                    .ignoresSafeArea(edges: displayMode == .safeArea ? .vertical : .all)

                if isAwaitingLandscape {
                    loadingIndicator
                } else if session.didFailToResolve {
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
                    loadingIndicator
                }
            }
            .scaleEffect(dismissScale, anchor: .top)
            .offset(y: dismissDragOffset)
        }
        .background(PlayerOrientationController(isRotating: $isRotating))
        .simultaneousGesture(displayModeGesture)
        .simultaneousGesture(dismissGesture)
        .sensoryFeedback(.selection, trigger: displayMode)
        .onChange(of: displayMode, initial: true) { applyCrop() }
        .onChange(of: surfaceSize) { applyCrop() }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { session.bind(appState: appState, subtitleStyleStore: subtitleStyleStore) }
        .onDisappear { session.end() }
        .onChange(of: session.isFinished) { _, isFinished in
            if isFinished { dismiss() }
        }
        .task(id: session.currentItem.id) {
            session.bind(appState: appState, subtitleStyleStore: subtitleStyleStore)
            await session.loadCurrentItem()
        }
        .task(id: session.currentMediaSourceID) {
            await session.loadTrickplay()
        }
    }

    private var isAwaitingLandscape: Bool {
        isRotating || (UIDevice.current.userInterfaceIdiom == .phone && surfaceSize.width <= surfaceSize.height)
    }

    private var loadingIndicator: some View {
        ProgressView()
            .tint(.white)
            .controlSize(.large)
    }

    // MARK: Swipe to dismiss

    private var dismissScale: CGFloat {
        guard surfaceSize.height > 0 else { return 1 }
        return max(0.8, 1 - dismissDragOffset / surfaceSize.height * 0.4)
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let translation = value.translation
                if !isDismissDragging {
                    guard !session.controller.isScrubbing,
                          translation.height > 0,
                          translation.height > abs(translation.width) else { return }
                    isDismissDragging = true
                }
                dismissDragOffset = max(0, translation.height)
            }
            .onEnded { value in
                guard isDismissDragging else { return }
                isDismissDragging = false
                if value.translation.height > Self.dismissDistance || value.predictedEndTranslation.height > Self.dismissPredictedDistance {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { dismissDragOffset = 0 }
                }
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

struct PlayerOrientationController: UIViewControllerRepresentable {
    @Binding var isRotating: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller(isRotating: $isRotating)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isRotating = $isRotating
    }

    final class Controller: UIViewController {
        var isRotating: Binding<Bool>

        init(isRotating: Binding<Bool>) {
            self.isRotating = isRotating
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            OrientationLock.set(.landscape)
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            isRotating.wrappedValue = true
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.isRotating.wrappedValue = false
            }
        }
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
            if isNil { OrientationLock.set(.portrait) }
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
