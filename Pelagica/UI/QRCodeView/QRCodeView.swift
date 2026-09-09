//
//  QRCodeView.swift
//  Pelagica
//

import SwiftUI

struct QRCodeView: View {
    let content: String
    
    var body: some View {
        if let cgImage = QRCodeGenerator.generate(from: content) {
            Image(decorative: cgImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.white
        }
    }
}
