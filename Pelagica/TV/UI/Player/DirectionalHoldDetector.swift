//
//  DirectionalHoldDetector.swift
//  Pelagica
//

import SwiftUI
import UIKit

/// Reports when the remote's left or right arrow is held down, and `nil` once it's released.
/// `onMoveCommand` only fires once per press, and SwiftUI has no press-down/press-up events on tvOS,
/// so this attaches press-only long-press recognizers to the window. They don't cancel the press,
/// so focus movement and `onMoveCommand` keep working.
struct DirectionalHoldDetector: UIViewRepresentable {
    var isEnabled: Bool
    let onChange: (MoveCommandDirection?) -> Void

    func makeUIView(context: Context) -> HoldView {
        let view = HoldView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: HoldView, context: Context) {
        view.onChange = onChange
        view.isEnabled = isEnabled
    }

    static func dismantleUIView(_ view: HoldView, coordinator: ()) {
        view.detach()
    }

    final class HoldView: UIView {
        var onChange: ((MoveCommandDirection?) -> Void)?
        var isEnabled = true {
            didSet { recognizers.forEach { $0.isEnabled = isEnabled } }
        }

        private var recognizers: [UILongPressGestureRecognizer] = []

        private static let minimumPressDuration: TimeInterval = 0.35

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let window else { return }
            recognizers = [
                makeRecognizer(for: .leftArrow, action: #selector(handleLeft(_:))),
                makeRecognizer(for: .rightArrow, action: #selector(handleRight(_:))),
            ]
            recognizers.forEach(window.addGestureRecognizer)
        }

        func detach() {
            recognizers.forEach { $0.view?.removeGestureRecognizer($0) }
            recognizers = []
        }

        private func makeRecognizer(for pressType: UIPress.PressType, action: Selector) -> UILongPressGestureRecognizer {
            let recognizer = UILongPressGestureRecognizer(target: self, action: action)
            recognizer.allowedPressTypes = [NSNumber(value: pressType.rawValue)]
            recognizer.allowedTouchTypes = []
            recognizer.minimumPressDuration = Self.minimumPressDuration
            recognizer.cancelsTouchesInView = false
            recognizer.isEnabled = isEnabled
            return recognizer
        }

        @objc private func handleLeft(_ recognizer: UILongPressGestureRecognizer) {
            handle(recognizer, direction: .left)
        }

        @objc private func handleRight(_ recognizer: UILongPressGestureRecognizer) {
            handle(recognizer, direction: .right)
        }

        private func handle(_ recognizer: UILongPressGestureRecognizer, direction: MoveCommandDirection) {
            switch recognizer.state {
            case .began: onChange?(direction)
            case .ended, .cancelled, .failed: onChange?(nil)
            default: break
            }
        }
    }
}
