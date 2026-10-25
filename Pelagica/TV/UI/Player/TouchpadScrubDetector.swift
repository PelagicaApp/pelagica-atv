//
//  TouchpadScrubDetector.swift
//  Pelagica
//

import SwiftUI
import UIKit

struct TouchpadScrubDetector: UIViewRepresentable {
    enum Event {
        case began
        case scrub(TimeInterval)
        case ended
    }

    var isEnabled: Bool
    let onEvent: (Event) -> Void

    func makeUIView(context: Context) -> PanView {
        let view = PanView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: PanView, context: Context) {
        view.onEvent = onEvent
        view.isEnabled = isEnabled
    }

    static func dismantleUIView(_ view: PanView, coordinator: ()) {
        view.detach()
    }

    final class PanView: UIView, UIGestureRecognizerDelegate {
        var onEvent: ((Event) -> Void)?
        var isEnabled = true {
            didSet { recognizer?.isEnabled = isEnabled }
        }

        private var recognizer: UIPanGestureRecognizer?
        private var lastTranslationX: CGFloat = 0
        private var axis: Axis = .undecided

        private enum Axis {
            case undecided
            case horizontal
            case vertical
        }

        private static let secondsPerSurfaceWidth: TimeInterval = 90
        private static let maxSpeedMultiplier: Double = 6
        private static let flickSecondsPerVelocitySquared: TimeInterval = 8
        private static let maxFlickSeconds: TimeInterval = 600
        private static let minFlickVelocity: Double = 1.5
        private static let deadZone: CGFloat = 0.05

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let window else { return }
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            recognizer.isEnabled = isEnabled
            window.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
        }

        func detach() {
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view, view.bounds.width > 0 else { return }
            
            let width = view.bounds.width
            let translation = recognizer.translation(in: view)
            let velocity = recognizer.velocity(in: view)

            switch recognizer.state {
            case .began, .changed:
                if axis == .undecided {
                    let distanceX = abs(translation.x) / width
                    let distanceY = abs(translation.y) / width
                    guard max(distanceX, distanceY) >= Self.deadZone else { return }
                    axis = distanceX > distanceY ? .horizontal : .vertical
                    guard axis == .horizontal else { return }
                    lastTranslationX = translation.x
                    onEvent?(.began)
                    return
                }
                guard axis == .horizontal else { return }
                let delta = Double((translation.x - lastTranslationX) / width)
                lastTranslationX = translation.x
                let speed = Double(abs(velocity.x) / width)
                let multiplier = min(max(1, speed), Self.maxSpeedMultiplier)
                onEvent?(.scrub(delta * Self.secondsPerSurfaceWidth * multiplier))
            case .ended, .cancelled, .failed:
                defer { axis = .undecided }
                guard axis == .horizontal else { return }
                let speed = Double(velocity.x / width)
                if recognizer.state == .ended, abs(speed) >= Self.minFlickVelocity {
                    let flick = min(speed * speed * Self.flickSecondsPerVelocitySquared, Self.maxFlickSeconds)
                    onEvent?(.scrub(speed < 0 ? -flick : flick))
                }
                onEvent?(.ended)
            default:
                break
            }
        }
    }
}
