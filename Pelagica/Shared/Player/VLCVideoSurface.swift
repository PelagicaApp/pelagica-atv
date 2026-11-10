//
//  VLCVideoSurface.swift
//  Pelagica
//

import SwiftUI
import UIKit

/// Hosts the view VLC renders into.
struct VLCVideoSurface: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
